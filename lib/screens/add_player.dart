import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/database/database.dart';
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
    _pastplayers = []; // Initialize to avoid late initialization error
    _loadPastPlayers();
  }

  Future<void> _loadPastPlayers() async {
    final dbHelper = ref.read(databaseProvider);
    try {
      final players = await dbHelper.getPastPlayers();
      if (mounted) {
        setState(() {
          _pastplayers = players;
        });
      }
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
        final int initialFee = calculatePreCheckInFee(
          hoursReserved: hoursReserved,
          minutesReserved: minutesReserved,
          prices: prices,
          isOpenTime: isOpenTime,
        );

        return Scaffold(
          appBar: const MyAppBar(),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Page Title
                const Text(
                  'Add New Player',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Main content area
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor:
                            0.75, // Content will take 75% of screen width
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column with scrollable content
                            Expanded(
                              flex: 3,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Name Field with enhanced styling
                                    Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.only(bottom: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Player Details',
                                              style: AppTextStyles
                                                  .sectionHeaderStyle
                                                  .copyWith(
                                                      color: Colors.black),
                                            ),
                                            const SizedBox(height: 16),
                                            // Name field with autocomplete
                                            Autocomplete<Player>(
                                              optionsBuilder: (TextEditingValue
                                                  textEditingValue) {
                                                if (textEditingValue
                                                    .text.isEmpty) {
                                                  return const Iterable<
                                                      Player>.empty();
                                                }
                                                final fuse = Fuzzy(
                                                  _pastplayers,
                                                  options: FuzzyOptions(
                                                    keys: [
                                                      WeightedKey(
                                                          name: 'name',
                                                          weight: 1.0,
                                                          getter:
                                                              (Player player) =>
                                                                  player.name)
                                                    ],
                                                    threshold: 0.5,
                                                  ),
                                                );

                                                final results = fuse.search(
                                                    textEditingValue.text);
                                                return results.map(
                                                    (result) => result.item);
                                              },
                                              displayStringForOption: (Player
                                                      option) =>
                                                  '${option.name} (${option.age})',
                                              onSelected:
                                                  (Player selection) async {
                                                final db =
                                                    ref.read(databaseProvider);
                                                final playerPhones =
                                                    await db.getPhoneNumbers(
                                                        selection.playerID);
                                                setState(() {
                                                  _selectedPlayer = selection;
                                                  nameController.text =
                                                      selection.name;
                                                  ageController.text =
                                                      selection.age.toString();
                                                  phoneControllers.clear();

                                                  // player phones
                                                  if (playerPhones.isEmpty) {
                                                    phoneControllers.add(
                                                        TextEditingController());
                                                  } else {
                                                    for (var phone
                                                        in playerPhones) {
                                                      phoneControllers.add(
                                                          TextEditingController(
                                                              text: phone));
                                                    }
                                                  }
                                                });
                                              },
                                              fieldViewBuilder: (context,
                                                  controller,
                                                  focusNode,
                                                  onFieldSubmitted) {
                                                return TextFormField(
                                                  controller: nameController,
                                                  focusNode: focusNode,
                                                  style: AppTextStyles
                                                      .regularTextStyle,
                                                  decoration: InputDecoration(
                                                    labelText: 'Name',
                                                    labelStyle: AppTextStyles
                                                        .regularTextStyle,
                                                    hintText:
                                                        'Enter player name',
                                                    hintStyle: AppTextStyles
                                                        .subtitleTextStyle,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 16,
                                                            vertical: 18),
                                                    suffixIcon:
                                                        _selectedPlayer != null
                                                            ? IconButton(
                                                                icon: const Icon(
                                                                    Icons.clear,
                                                                    size: 24),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _selectedPlayer =
                                                                        null;
                                                                    nameController
                                                                        .clear();
                                                                    ageController
                                                                        .clear();
                                                                    phoneControllers
                                                                        .clear();
                                                                    phoneControllers
                                                                        .add(
                                                                            TextEditingController());
                                                                  });
                                                                },
                                                              )
                                                            : null,
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Please enter a name';
                                                    }
                                                    return null;
                                                  },
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 24),

                                            // Age
                                            TextFormField(
                                              controller: ageController,
                                              style: AppTextStyles
                                                  .regularTextStyle,
                                              decoration: InputDecoration(
                                                labelText: 'Age',
                                                labelStyle: AppTextStyles
                                                    .regularTextStyle,
                                                hintText: 'Enter player age',
                                                hintStyle: AppTextStyles
                                                    .subtitleTextStyle,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 18),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly
                                              ],
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please enter an age';
                                                }
                                                final age = int.tryParse(value);
                                                if (age == null || age < 0) {
                                                  return 'Please enter a valid age';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Phone Numbers Section
                                    Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.only(bottom: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Phone Numbers (optional)',
                                              style: AppTextStyles
                                                  .sectionHeaderStyle
                                                  .copyWith(
                                                      color: Colors.black),
                                            ),
                                            const SizedBox(height: 16),
                                            for (int i = 0;
                                                i < phoneControllers.length;
                                                i++)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller:
                                                            phoneControllers[i],
                                                        style: AppTextStyles
                                                            .regularTextStyle,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText:
                                                              'Phone Number',
                                                          labelStyle: AppTextStyles
                                                              .regularTextStyle,
                                                          hintText:
                                                              'Enter phone number',
                                                          hintStyle: AppTextStyles
                                                              .subtitleTextStyle,
                                                          border:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 18),
                                                        ),
                                                        keyboardType:
                                                            TextInputType.phone,
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter
                                                              .digitsOnly
                                                        ],
                                                        validator: (value) {
                                                          if (value != null &&
                                                              value
                                                                  .isNotEmpty) {
                                                            final phone =
                                                                value.trim();
                                                            if (phone.length !=
                                                                10) {
                                                              return 'Please enter a valid phone number';
                                                            }
                                                            if (!phone
                                                                .startsWith(
                                                                    "09")) {
                                                              return 'Phone number must start with 09';
                                                            }
                                                            if (phone.contains(
                                                                RegExp(
                                                                    r'\D'))) {
                                                              return 'Phone number must contain only digits';
                                                            }
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ),
                                                    if (i ==
                                                        phoneControllers
                                                                .length -
                                                            1) ...[
                                                      const SizedBox(width: 12),
                                                      SizedBox(
                                                        width: 48,
                                                        height: 48,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                              Icons.add,
                                                              size: 28),
                                                          tooltip:
                                                              'Add phone number',
                                                          onPressed: () {
                                                            setState(() {
                                                              phoneControllers.add(
                                                                  TextEditingController());
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      if (phoneControllers
                                                              .length >
                                                          1)
                                                        const SizedBox(
                                                            width: 8),
                                                      if (phoneControllers
                                                              .length >
                                                          1)
                                                        SizedBox(
                                                          width: 48,
                                                          height: 48,
                                                          child: IconButton(
                                                            icon: const Icon(
                                                                Icons.remove,
                                                                size: 28),
                                                            tooltip:
                                                                'Remove phone number',
                                                            onPressed: () {
                                                              setState(() {
                                                                phoneControllers
                                                                    .removeAt(
                                                                        i);
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Time Reservation Section
                                    Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.only(bottom: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Time Reservation',
                                              style: AppTextStyles
                                                  .sectionHeaderStyle
                                                  .copyWith(
                                                      color: Colors.black),
                                            ),
                                            const SizedBox(height: 24),

                                            // Reserved Time Display
                                            Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16,
                                                        horizontal: 24),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade300),
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
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24,
                                                        vertical: 16),
                                                    textStyle: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  child: Text(
                                                    "+1 Hour",
                                                    style: AppTextStyles
                                                        .primaryButtonTextStyle
                                                        .copyWith(fontSize: 18),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (!isOpenTime &&
                                                          hoursReserved <= 12) {
                                                        hoursReserved++;
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 16),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24,
                                                        vertical: 16),
                                                    textStyle: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  child: Text(
                                                    "+30 Minutes",
                                                    style: AppTextStyles
                                                        .primaryButtonTextStyle
                                                        .copyWith(fontSize: 18),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (!isOpenTime &&
                                                          minutesReserved ==
                                                              0) {
                                                        minutesReserved = 30;
                                                      } else if (!isOpenTime &&
                                                          minutesReserved ==
                                                              30 &&
                                                          hoursReserved < 12) {
                                                        hoursReserved++;
                                                        minutesReserved = 0;
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 16),
                                                OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24,
                                                        vertical: 16),
                                                    textStyle: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  child: Text(
                                                    "Reset",
                                                    style: AppTextStyles
                                                        .primaryButtonTextStyle
                                                        .copyWith(fontSize: 18),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      hoursReserved = 0;
                                                      minutesReserved = 0;
                                                      isOpenTime = false;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 24),

                                            // Open Time Toggle
                                            Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Transform.scale(
                                                      scale: 1.4,
                                                      child: Checkbox(
                                                        value: isOpenTime,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            isOpenTime =
                                                                value ?? false;
                                                            if (isOpenTime) {
                                                              hoursReserved = 0;
                                                              minutesReserved =
                                                                  0;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Open Time',
                                                      style: AppTextStyles
                                                          .tableCellStyle,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Right column with payment details and add player button
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Summary',
                                        style: AppTextStyles.sectionHeaderStyle
                                            .copyWith(color: Colors.black),
                                      ),
                                      const SizedBox(height: 32),

                                      // Fee summary display
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 24),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.blue.shade100),
                                        ),
                                        child: Column(
                                          children: [
                                            const Text(
                                              'Total Fee',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              isOpenTime
                                                  ? 'Open Time'
                                                  : '$initialFee  SYP',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Input for amount paid on check-in
                                      TextFormField(
                                        controller: amountPaidController,
                                        style: const TextStyle(fontSize: 18),
                                        decoration: InputDecoration(
                                            labelText:
                                                'Amount Paid on Check-in',
                                            labelStyle:
                                                AppTextStyles.regularTextStyle,
                                            hintText: 'Enter amount paid',
                                            hintStyle:
                                                AppTextStyles.subtitleTextStyle,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 18),
                                            prefixText: 'SYP   ',
                                            prefixStyle: AppTextStyles
                                                .regularTextStyle
                                                .copyWith(color: Colors.black)),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
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

                                      const SizedBox(height: 24),
                                      const Divider(),
                                      const SizedBox(height: 16),

                                      // Submit Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 60,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            textStyle: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () => _handleCheckIn(
                                              prices, initialFee),
                                          child: const Text("Add Player"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
      ),
    );
  }

  void _handleCheckIn(Map<TimeSlice, int> prices, int initialFee) {
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
          existingPlayerID: _selectedPlayer?.playerID,
          name: name,
          age: age,
          timeReservedHours: hoursReserved,
          timeReservedMinutes: minutesReserved,
          isOpenTime: isOpenTime,
          totalFee: initialFee,
          amountPaid: amountPaid,
          phoneNumbers: phoneNumbers,
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Player added successfully!'),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    for (var controller in phoneControllers) {
      controller.dispose();
    }
    amountPaidController.dispose();
    super.dispose();
  }
}
