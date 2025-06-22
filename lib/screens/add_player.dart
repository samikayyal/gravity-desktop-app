import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';

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

  Player? _selectedPlayer; // exists if we chose an existing player
  late List<Player> _pastplayers; // list of past players to search in

  @override
  void initState() {
    super.initState();
    _loadPastPlayers();
  }

  Future<void> _loadPastPlayers() async {
    final dbHelper = ref.read(databaseProvider);
    try {
      final players = await dbHelper.getPastPlayers();
      setState(() {
        _pastplayers = players;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading past players: $e')),
        );
      }
    }
  }

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
                    Autocomplete<Player>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Player>.empty();
                        }
                        final fuse = Fuzzy(
                          _pastplayers,
                          options: FuzzyOptions(
                            keys: [
                              WeightedKey(
                                  name: 'name',
                                  weight: 1.0,
                                  getter: (Player player) => player.name)
                            ],
                            threshold: 0.3, // Adjust threshold for matching
                          ),
                        );

                        final results = fuse.search(textEditingValue.text);
                        return results.map((result) => result.item);
                      },
                      // this defines how to display the selected option
                      displayStringForOption: (Player option) =>
                          '${option.name} (${option.age})',

                      // this runs when the user accepts a suggestion
                      onSelected: (Player selection) async {
                        final db = ref.read(databaseProvider);
                        final playerPhones =
                            await db.getPhoneNumbers(selection.playerID);
                        setState(() {
                          _selectedPlayer = selection;
                          ageController.text = selection.age.toString();
                          // Clear phone numbers if a player is selected
                          phoneControllers.clear();
                          for (var phone in playerPhones) {
                            phoneControllers
                                .add(TextEditingController(text: phone));
                          }
                        });
                      },
                      // this builds the input field
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: nameController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: 'Enter player name',
                            // Add a clear button to reset the selection
                            suffixIcon: _selectedPlayer != null
                                ? IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _selectedPlayer = null;
                                        nameController.clear();
                                        ageController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        );
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
                        : 'Total Fee: ${calculatePreCheckInFee(hoursReserved: hoursReserved, minutesReserved: minutesReserved, prices: prices, isOpenTime: isOpenTime)} SYP'),

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
                        final name =
                            _selectedPlayer?.name ?? nameController.text;
                        final age = int.parse(ageController.text);
                        final phoneNumbers = phoneControllers
                            .map((controller) => controller.text)
                            .where((phone) => phone.isNotEmpty)
                            .toList();

                        final amountPaid = int.parse(amountPaidController.text);

                        ref.read(currentPlayersProvider.notifier).checkInPlayer(
                              existingPlayerID: _selectedPlayer?.playerID,
                              name: name,
                              age: age,
                              timeReservedHours: hoursReserved,
                              timeReservedMinutes: minutesReserved,
                              isOpenTime: isOpenTime,
                              totalFee: calculatePreCheckInFee(
                                hoursReserved: hoursReserved,
                                minutesReserved: minutesReserved,
                                prices: prices,
                                isOpenTime: isOpenTime,
                              ),
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

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    for (var controller in phoneControllers) {
      controller.dispose();
    }
    amountPaidController.dispose();
    _pastplayers.clear();
    _selectedPlayer = null;
    super.dispose();
  }
}
