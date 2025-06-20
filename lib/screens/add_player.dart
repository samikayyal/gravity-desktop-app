import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

class AddPlayerScreen extends ConsumerStatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  ConsumerState<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends ConsumerState<AddPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  int hoursReserved = 0;
  int minutesReserved = 0;
  int amountPaid = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Form to add a player
          Center(
            child: SizedBox(
              width: 400,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter player name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        hintText: 'Enter player age',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an age';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age <= 0) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter player phone number',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        // Add more validation for phone number if needed
                        return null;
                      },
                    ),

                    // Reserve Time
                    Text("$hoursReserved Hours $minutesReserved Minutes"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                            onPressed: () {
                              setState(() {
                                if (hoursReserved < 12) {
                                  hoursReserved++;
                                }
                              });
                            },
                            child: Text("+1 Hour")),
                        TextButton(
                            onPressed: () {
                              setState(() {
                                if (minutesReserved == 0) {
                                  minutesReserved = 30;
                                } else if (minutesReserved == 30 &&
                                    hoursReserved < 12) {
                                  minutesReserved = 0;
                                  hoursReserved++;
                                }
                              });
                            },
                            child: Text("+30 Minutes")),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              hoursReserved = 0;
                              minutesReserved = 0;
                            });
                          },
                          child: Text("Reset"),
                        )
                      ],
                    ),

                    // Total Amount Owed
                    Text()
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  int calculateTotalAmountOwed() {
    Map<TimeSlice, int> prices = ref.read(pricesProvider);
  }
}
