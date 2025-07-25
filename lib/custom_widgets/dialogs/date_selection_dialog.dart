// ignore: unused_import
import 'dart:developer';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
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
      width: 580,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mainBlue.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.date_range_outlined,
                  color: mainBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Select Date Range",
                style: AppTextStyles.sectionHeaderStyle,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Date selection options in organized cards
          Row(
            children: [
              // Custom Date Selection Card
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: mainBlue,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Custom Selection",
                        style: AppTextStyles.subtitleTextStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Choose single, range, or multiple dates",
                        style: AppTextStyles.subtitleTextStyle.copyWith(
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            _dateSelectionType = null;
                            final List<DateTime?> results =
                                await _showDatePickerDialog(context);

                            setState(() {
                              _dates = results;
                            });
                          },
                          style: AppButtonStyles.primaryButton.copyWith(
                            minimumSize:
                                WidgetStateProperty.all(const Size(0, 44)),
                          ),
                          child: Text(
                            "Select Dates",
                            style: AppTextStyles.primaryButtonTextStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Quick Select Card
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flash_on_outlined,
                        color: mainBlue,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Quick Select",
                        style: AppTextStyles.subtitleTextStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Common date selections",
                        style: AppTextStyles.subtitleTextStyle.copyWith(
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: AppButtonStyles.primaryButton.copyWith(
                                minimumSize:
                                    WidgetStateProperty.all(const Size(0, 44)),
                              ),
                              onPressed: () => setState(() {
                                _dateSelectionType = DateSelectionType.single;
                                _dates = [DateTime.now()];
                              }),
                              child: Text(
                                "Today",
                                style: AppTextStyles.primaryButtonTextStyle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: AppButtonStyles.primaryButton.copyWith(
                                minimumSize:
                                    WidgetStateProperty.all(const Size(0, 44)),
                              ),
                              onPressed: () => setState(() {
                                _dateSelectionType = DateSelectionType.single;
                                _dates = [
                                  DateTime.now()
                                      .subtract(const Duration(days: 1)),
                                ];
                              }),
                              child: Text(
                                "Yesterday",
                                style: AppTextStyles.primaryButtonTextStyle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                _dateSelectionType = DateSelectionType.range;
                                final lastSaturday = getLastSaturday(
                                  fromDate: DateTime.now(),
                                );

                                // If today is Saturday, select only that date.
                                if (DateTime.now().toYYYYMMDD() ==
                                    lastSaturday.toYYYYMMDD()) {
                                  _dateSelectionType = DateSelectionType.single;
                                  _dates = [lastSaturday];
                                } else {
                                  _dateSelectionType = DateSelectionType.range;
                                  final startDate = lastSaturday;
                                  final endDate = DateTime.now();
                                  _dates = List.generate(
                                    endDate.difference(startDate).inDays + 1,
                                    (index) =>
                                        startDate.add(Duration(days: index)),
                                  );
                                }
                              }),
                              style: AppButtonStyles.primaryButton.copyWith(
                                minimumSize:
                                    WidgetStateProperty.all(const Size(0, 44)),
                              ),
                              child: Text(
                                "This Business Week",
                                style: AppTextStyles.primaryButtonTextStyle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: AppButtonStyles.primaryButton.copyWith(
                                minimumSize:
                                    WidgetStateProperty.all(const Size(0, 44)),
                              ),
                              onPressed: () => setState(() {
                                final lastSaturday = getLastSaturday(
                                  fromDate: DateTime.now(),
                                  oneBeforeLast: true,
                                );

                                // If today is Saturday, select only that date.
                                if (DateTime.now().toYYYYMMDD() ==
                                    lastSaturday.toYYYYMMDD()) {
                                  _dateSelectionType = DateSelectionType.single;
                                  _dates = [lastSaturday];
                                } else {
                                  _dateSelectionType = DateSelectionType.range;
                                  final startDate = lastSaturday;
                                  final endDate = getLastSaturday(
                                          fromDate: DateTime.now())
                                      .subtract(Duration(days: 1)); // sunday
                                  _dates = List.generate(
                                    endDate.difference(startDate).inDays + 1,
                                    (index) =>
                                        startDate.add(Duration(days: index)),
                                  );
                                }
                              }),
                              child: Text(
                                "Last Business Week",
                                style: AppTextStyles.primaryButtonTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Selected dates display with enhanced styling
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mainBlue.withAlpha(13),
                  mainBlue.withAlpha(26),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mainBlue.withAlpha(51)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: mainBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Selected Dates",
                      style: AppTextStyles.subtitleTextStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: mainBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_dates.isEmpty)
                  Text(
                    "No dates selected",
                    style: AppTextStyles.subtitleTextStyle.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _dateSelectionType == DateSelectionType.range
                          ? "${_dates.first?.toYYYYMMDD()} ➜ ${_dates.last?.toYYYYMMDD()}"
                          : _dates.map((e) => e?.toYYYYMMDD()).join(' • '),
                      style: AppTextStyles.amountTextStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
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
                width: MediaQuery.of(context).size.width * 0.35,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: mainBlue.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_view_month_outlined,
                            color: mainBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Select Date Picker Mode",
                          style: AppTextStyles.sectionHeaderStyle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Mode selection with enhanced buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Choose selection mode",
                            style: AppTextStyles.subtitleTextStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        ],
                      ),
                    ),

                    if (_dateSelectionType != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CalendarDatePicker2(
                          config: CalendarDatePicker2Config(
                              // text styles
                              dayTextStyle: AppTextStyles.regularTextStyle,
                              monthTextStyle: AppTextStyles.regularTextStyle,
                              todayTextStyle:
                                  AppTextStyles.regularTextStyle.copyWith(
                                color: mainBlue,
                                fontWeight: FontWeight.w600,
                              ),
                              selectedYearTextStyle:
                                  AppTextStyles.regularTextStyle,
                              yearTextStyle: AppTextStyles.regularTextStyle,
                              selectedMonthTextStyle:
                                  AppTextStyles.regularTextStyle,
                              weekdayLabelTextStyle:
                                  AppTextStyles.subtitleTextStyle.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14),
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
                                _dates = [
                                  value.isNotEmpty ? value.first : null
                                ];
                                break;
                              case DateSelectionType.multi:
                                _dates = value;
                                break;
                              default:
                                _dates = [];
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
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
