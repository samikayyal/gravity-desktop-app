import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';

class AddPlayerScreen extends ConsumerStatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  ConsumerState<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends ConsumerState<AddPlayerScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController nameController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  List<TextEditingController> phoneControllers = [TextEditingController()];
  TextEditingController amountPaidController = TextEditingController(text: '0');

  int hoursReserved = 0;
  int minutesReserved = 0;
  bool isOpenTime = false;
  int totalFee = 0;

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);
    return pricesAsync.when(
        data: (prices) {
          return Scaffold(
              appBar: const MyAppBar(),
              body: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Name
                    TextFormField(
                      controller: nameController,
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

                    // Age
                    TextFormField(
                      controller: ageController,
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
                        if (age == null || age < 0) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),

                    // Phone Numbers
                    const Text('Phone Numbers (optional)'),
                    for (int i = 0; i < phoneControllers.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: phoneControllers[i],
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'Enter phone number',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final phone = value.trim();
                                  if (phone.length != 10) {
                                    return 'Please enter a valid phone number';
                                  }
                                  if (!phone.startsWith("09")) {
                                    return 'Phone number must start with 09';
                                  }
                                  if (phone.contains(RegExp(r'\D'))) {
                                    return 'Phone number must contain only digits';
                                  }
                                }
                                return null; // No validation for empty
                              },
                            ),
                          ),
                          if (i == phoneControllers.length - 1) ...[
                            // the ... is used to add widgets to the rows children
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Add phone number',
                              onPressed: () {
                                setState(() {
                                  phoneControllers.add(TextEditingController());
                                });
                              },
                            ),
                            if (phoneControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove),
                                tooltip: 'Remove phone number',
                                onPressed: () {
                                  setState(() {
                                    phoneControllers.removeAt(i);
                                  });
                                },
                              ),
                          ]
                        ],
                      ),

                    // Reserved Time
                    Text(isOpenTime
                        ? 'Open Time'
                        : '$hoursReserved Hours $minutesReserved Minutes'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          child: Text("+1 Hour"),
                          onPressed: () {
                            setState(() {
                              if (!isOpenTime && hoursReserved <= 12) {
                                hoursReserved++;
                              }
                            });
                          },
                        ),
                        TextButton(
                          child: Text("+30 Minutes"),
                          onPressed: () {
                            setState(() {
                              if (!isOpenTime && minutesReserved == 0) {
                                minutesReserved = 30;
                              } else if (!isOpenTime &&
                                  minutesReserved == 30 &&
                                  hoursReserved < 12) {
                                hoursReserved++;
                                minutesReserved = 0;
                              }
                            });
                          },
                        ),
                        TextButton(
                          child: Text("Reset"),
                          onPressed: () {
                            setState(() {
                              hoursReserved = 0;
                              minutesReserved = 0;
                              isOpenTime = false;
                            });
                          },
                        )
                      ],
                    ),

                    // Open Time Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
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
                        const Text('Open Time'),
                      ],
                    ),
                    // Display total fee
                    Text(isOpenTime
                        ? 'Total Fee: Open Time'
                        : 'Total Fee: ${calculateTotalFee(hoursReserved: hoursReserved, minutesReserved: minutesReserved, prices: prices, isOpenTime: isOpenTime)} SYP'),

                    // Input for amount paid on check-in
                    TextFormField(
                      controller: amountPaidController,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid on Check-in',
                        hintText: 'Enter amount paid',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = int.tryParse(value);
                        if (amount == null || amount < 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),

                    // Submit Button
                    ElevatedButton(
                      child: Text("Add Player"),
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }
                        final name = nameController.text;
                        final age = int.parse(ageController.text);
                        final phoneNumbers = phoneControllers
                            .map((controller) => controller.text)
                            .where((phone) => phone.isNotEmpty)
                            .toList();

                        final amountPaid = int.parse(amountPaidController.text);

                        ref.read(currentPlayersProvider.notifier).checkInPlayer(
                              name: name,
                              age: age,
                              timeReservedHours: hoursReserved,
                              timeReservedMinutes: minutesReserved,
                              isOpenTime: isOpenTime,
                              totalFee: isOpenTime
                                  ? 0
                                  : (hoursReserved * prices[TimeSlice.hour]! +
                                      (minutesReserved > 0
                                          ? prices[TimeSlice.halfHour]!
                                          : 0)),
                              amountPaid: amountPaid,
                              phoneNumbers: phoneNumbers,
                            );

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Player added successfully!'),
                          ),
                        );
                      },
                    )
                  ],
                ),
              ));
        },
        error: (err, stack) => Scaffold(
              appBar: const MyAppBar(),
              body: Center(
                child: Text('Error loading prices: $err'),
              ),
            ),
        loading: () => Scaffold(
              appBar: const MyAppBar(),
              body: const Center(child: CircularProgressIndicator()),
            ));
  }
}

int calculateTotalFee({
  required int hoursReserved,
  required int minutesReserved,
  required Map<TimeSlice, int> prices,
  required bool isOpenTime,
}) {
  // Open time has no fee
  if (isOpenTime) return 0;
  if (hoursReserved == 0 && minutesReserved == 0) {
    return 0; // No time reserved, no fee
  }

  int total = 0;
  // If there is at least 1 hour, charge first hour at base price
  if (hoursReserved > 0) {
    total += prices[TimeSlice.hour]!;
    if (hoursReserved > 1) {
      total += (hoursReserved - 1) * (prices[TimeSlice.additionalHour]!);
    }
    // If there is a half hour, charge it at additional half hour price
    if (minutesReserved == 30) {
      total += prices[TimeSlice.additionalHalfHour]!;
    }
  } else if (minutesReserved == 30) {
    // No full hour, charge first half hour at base price
    total += prices[TimeSlice.halfHour]!;
  }
  return total;
}
