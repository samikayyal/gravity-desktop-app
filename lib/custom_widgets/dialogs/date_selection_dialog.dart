// ignore: unused_import
import 'dart:developer';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/utils/general.dart';

enum DateSelectionType {
  range,
  single,
  multi,
}

class DateSelectionDialog extends StatefulWidget {
  const DateSelectionDialog({super.key});

  @override
  State<DateSelectionDialog> createState() => _DateSelectionDialogState();
}

class _DateSelectionDialogState extends State<DateSelectionDialog> {
  DateSelectionType? _dateSelectionType;
  List<DateTime?> _dates = [
    // DateTime.now().subtract(const Duration(days: 7)),
    // DateTime.now()
  ];
  @override
  Widget build(BuildContext context) {
    return MyDialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Select Date Range",
            style: AppTextStyles.sectionHeaderStyle,
          ),
          const SizedBox(height: 16),

          // Date Range Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // left side
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      _dateSelectionType = null;
                      final List<DateTime?> results =
                          await _showDatePickerDialog(context);

                      setState(() {
                        _dates = results;
                      });
                    },
                    style: AppButtonStyles.primaryButton,
                    child: Text(
                      "Select Dates",
                      style: AppTextStyles.primaryButtonTextStyle,
                    ),
                  ),
                ],
              ),

              // right side
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Quick Select",
                    style: AppTextStyles.regularTextStyle,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: AppButtonStyles.primaryButton,
                    onPressed: () => setState(() {
                      _dateSelectionType = DateSelectionType.single;
                      _dates = [
                        DateTime.now(),
                      ];
                    }),
                    child: Text(
                      "Today",
                      style: AppTextStyles.primaryButtonTextStyle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: AppButtonStyles.primaryButton,
                    onPressed: () => setState(() {
                      _dateSelectionType = DateSelectionType.range;
                      _dates = [
                        DateTime.now().subtract(const Duration(days: 1)),
                      ];
                    }),
                    child: Text(
                      "Yesterday",
                      style: AppTextStyles.primaryButtonTextStyle,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          // Show the selected dates
          Center(
            child: MyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Selected Dates",
                      style: AppTextStyles.sectionHeaderStyle),
                  Text(
                    _dateSelectionType == DateSelectionType.range
                        ? "${_dates.first?.toYYYYMMDD()} ➜ ${_dates.last?.toYYYYMMDD()}"
                        : _dates.map((e) => e?.toYYYYMMDD()).join(' - '),
                    style: AppTextStyles.amountTextStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // action buttons
          _buildActionButtons()
        ],
      ),
    );
  }

  Future<List<DateTime?>> _showDatePickerDialog(BuildContext context) async {
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return MyDialog(
                width: MediaQuery.of(context).size.width * 0.3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Select Date Picker Mode",
                      style: AppTextStyles.sectionHeaderStyle,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                              onPressed: _dateSelectionType == null
                                  ? () {
                                      setDialogState(() {
                                        _dateSelectionType =
                                            DateSelectionType.single;
                                      });
                                    }
                                  : null,
                              style: _dateSelectionType == null
                                  ? AppButtonStyles.primaryButton
                                  : AppButtonStyles.secondaryButton,
                              child: Text("Single",
                                  style: _dateSelectionType ==
                                          DateSelectionType.single
                                      ? AppTextStyles.primaryButtonTextStyle
                                      : AppTextStyles
                                          .secondaryButtonTextStyle)),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: _dateSelectionType == null
                                  ? () {
                                      setDialogState(() {
                                        _dateSelectionType =
                                            DateSelectionType.range;
                                      });
                                    }
                                  : null,
                              style: _dateSelectionType == null
                                  ? AppButtonStyles.primaryButton
                                  : AppButtonStyles.secondaryButton,
                              child: Text("Range",
                                  style: _dateSelectionType ==
                                          DateSelectionType.range
                                      ? AppTextStyles.primaryButtonTextStyle
                                      : AppTextStyles
                                          .secondaryButtonTextStyle)),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: _dateSelectionType == null
                                  ? () {
                                      setDialogState(() {
                                        _dateSelectionType =
                                            DateSelectionType.multi;
                                      });
                                    }
                                  : null,
                              style: _dateSelectionType == null
                                  ? AppButtonStyles.primaryButton
                                  : AppButtonStyles.secondaryButton,
                              child: Text("Multi",
                                  style: _dateSelectionType ==
                                          DateSelectionType.multi
                                      ? AppTextStyles.primaryButtonTextStyle
                                      : AppTextStyles
                                          .secondaryButtonTextStyle)),
                        ],
                      ),
                    ),
                    if (_dateSelectionType != null) ...[
                      CalendarDatePicker2(
                        config: CalendarDatePicker2Config(
                            // text styles
                            dayTextStyle: AppTextStyles.regularTextStyle,
                            monthTextStyle: AppTextStyles.regularTextStyle,
                            todayTextStyle: AppTextStyles.regularTextStyle,
                            selectedYearTextStyle:
                                AppTextStyles.regularTextStyle,
                            yearTextStyle: AppTextStyles.regularTextStyle,
                            selectedMonthTextStyle:
                                AppTextStyles.regularTextStyle,
                            weekdayLabelTextStyle:
                                AppTextStyles.subtitleTextStyle.copyWith(
                                    fontWeight: FontWeight.w500, fontSize: 14),
                            //calendar type
                            calendarType: switch (_dateSelectionType) {
                              DateSelectionType.range =>
                                CalendarDatePicker2Type.range,
                              DateSelectionType.single =>
                                CalendarDatePicker2Type.single,
                              DateSelectionType.multi =>
                                CalendarDatePicker2Type.multi,
                              _ => CalendarDatePicker2Type.range,
                            },
                            lastDate: DateTime.now()),
                        value: [],
                        onValueChanged: (value) {
                          switch (_dateSelectionType) {
                            case DateSelectionType.range:
                              // if its a range, have all the dates between the
                              // start and end date in the list
                              if (value.isNotEmpty) {
                                final startDate = value.first;
                                final endDate = value.last;
                                _dates = List.generate(
                                  endDate.difference(startDate).inDays + 1,
                                  (index) =>
                                      startDate.add(Duration(days: index)),
                                );
                              } else {
                                _dates = [];
                              }
                              break;
                            case DateSelectionType.single:
                              _dates = [value.isNotEmpty ? value.first : null];
                              break;
                            case DateSelectionType.multi:
                              _dates = value;
                              break;
                            default:
                              _dates = [];
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildActionButtons()
                  ],
                ),
              );
            },
          );
        });
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              _dateSelectionType = null;
              _dates = [];
            });
            Navigator.of(context).pop(<DateTime?>[]);
          },
          style: AppButtonStyles.secondaryButton,
          child: Text(
            "Cancel",
            style: AppTextStyles.secondaryButtonTextStyle,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _dateSelectionType == null
              ? null
              : () {
                  Navigator.of(context).pop(_dates);
                },
          style: AppButtonStyles.primaryButton,
          child: Text(
            "Confirm",
            style: AppTextStyles.primaryButtonTextStyle,
          ),
        ),
      ],
    );
  }
}
