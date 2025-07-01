import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';

enum ScreenState {
  viewSubs,
  addSub,
}

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsState();
}

class _SubscriptionsState extends ConsumerState<SubscriptionsScreen> {
  ScreenState _currentScreen = ScreenState.viewSubs;
  final formatter = NumberFormat.decimalPattern();

  // 'Add Subscription' Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final List<TextEditingController> _phoneControllers = [
    TextEditingController()
  ];
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '45');
  final TextEditingController _amountPaidController = TextEditingController();

  Player? _selectedPlayer;
  int _totalFee = 0;

  @override
  void initState() {
    super.initState();
    _hoursController.addListener(_updateFee);
    _discountController.addListener(_updateFee);
  }

  void _updateFee() {
    final pricesAsync = ref.watch(pricesProvider);

    pricesAsync.when(
      error: (error, stackTrace) {
        setState(() {
          _totalFee = 0;
        });
      },
      loading: () {
        setState(() {
          _totalFee = 0;
        });
      },
      data: (prices) {
        setState(() {
          _totalFee = calculateSubscriptionFee(
            hours: int.tryParse(_hoursController.text) ?? 0,
            discount: int.tryParse(_discountController.text) ?? 0,
            prices: prices,
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    _hoursController.dispose();
    _discountController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _ageController.clear();

    _phoneControllers.clear();
    _phoneControllers.add(TextEditingController());

    _hoursController.clear();
    _discountController.text = '0';
    _amountPaidController.clear();
    setState(() {
      _selectedPlayer = null;
      _totalFee = 0;
    });
  }

  void _handleAddSubscription() {
    final subs = ref.read(subscriptionsProvider.notifier);
    if (!_formKey.currentState!.validate()) return;

    final playerName = _selectedPlayer?.name ?? _nameController.text.trim();
    final playerAge =
        _selectedPlayer?.age ?? int.tryParse(_ageController.text.trim()) ?? 0;

    try {
      subs.addNewSubscription(
        playerName: playerName,
        age: playerAge,
        phoneNumbers: _phoneControllers.map((c) => c.text.trim()).toList(),
        hoursIncluded: int.tryParse(_hoursController.text.trim()) ?? 0,
        durationMinutes: 60 * 24 * 31, // 1 month
        discountPercent: int.tryParse(_discountController.text.trim()) ?? 0,
        totalFee: _totalFee,
        amountPaid: int.tryParse(_amountPaidController.text.trim()) ?? 0,
      );

      setState(() => _currentScreen = ScreenState.viewSubs);
    } catch (e) {
      MyMaterialBanner.showBanner(context,
          message: 'Error adding subscription: $e', type: MessageType.error);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Subscriptions',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildScreenToggler(),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentScreen == ScreenState.viewSubs
                    ? _buildViewSubscriptions()
                    : _buildAddSubscriptionForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenToggler() {
    return Center(
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(10),
        onPressed: (index) {
          setState(() {
            _currentScreen = ScreenState.values[index];
          });
        },
        isSelected: [
          _currentScreen == ScreenState.viewSubs,
          _currentScreen == ScreenState.addSub,
        ],
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Text('View Subscriptions', style: TextStyle(fontSize: 16)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Text('Add New Subscription', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSubscriptions() {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);

    return subscriptionsAsync.when(
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return Center(
            child: Text(
              'No active subscriptions found.',
              style: AppTextStyles.subtitleTextStyle,
            ),
          );
        }
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Phone Number')),
                DataColumn(label: Text('Initial Hours')),
                DataColumn(label: Text('Remaining')),
                DataColumn(label: Text('Expiry Date')),
                DataColumn(label: Text('Total Fee')),
                DataColumn(label: Text('Amount Left')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: subscriptions.map((sub) {
                final initialHours = sub.totalMinutes ~/ 60;

                final remainingHours = sub.remainingMinutes ~/ 60;
                final remainingMins = sub.remainingMinutes % 60;
                final String remainingString = remainingHours > 0
                    ? '$remainingHours h $remainingMins m'
                    : '$remainingMins m';

                return DataRow(
                  cells: [
                    // Name
                    DataCell(Text(sub.playerName)),
                    // Phone
                    DataCell(Text(sub.phoneNumbers.firstOrNull ?? 'N/A')),
                    // Initial Hours
                    DataCell(Text('$initialHours h')),
                    // Remaining
                    DataCell(Text(remainingString)),
                    // Expiry Date
                    DataCell(Text(
                      DateFormat('yyyy-MM-dd').format(sub.expiryDate),
                    )),
                    // Total Fee
                    DataCell(Text('${sub.totalFee}')),
                    // Amount Left
                    DataCell(Text('${sub.totalFee - sub.amountPaid}')),
                    // Status
                    DataCell(Text(sub.status.toTitleCase())),
                    // Actions
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: []))
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
      error: (err, stack) {
        debugPrint('Error in subs table: $err\n$stack');
        return Center(child: Text('Error: $err'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAddSubscriptionForm() {
    final pricesAsync = ref.watch(pricesProvider);

    return pricesAsync.when(
      data: (prices) {
        // Trigger a fee update if prices load after controllers have values
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateFee());
        return Form(
          key: _formKey,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Player and Subscription Details
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPlayerDetailsCard(),
                          _buildPhoneNumbersCard(),
                          _buildSubscriptionDetailsCard(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Payment Summary
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _buildPaymentSummaryCard(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      error: (err, stack) => Center(child: Text('Error loading prices: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  MyCard _buildPlayerDetailsCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Player Details', style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 16),
          Autocomplete<Player>(
            // Autocomplete logic inspired directly from add_player.dart
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Player>.empty();
              }

              final pastPlayersAsync = ref.watch(pastPlayersProvider);
              return pastPlayersAsync.when(
                  error: (err, stack) => const Iterable<Player>.empty(),
                  loading: () => const Iterable<Player>.empty(),
                  data: (pastPlayers) {
                    final fuse = Fuzzy(
                      pastPlayers,
                      options: FuzzyOptions(
                        keys: [
                          WeightedKey(
                              name: 'name',
                              weight: 1.0,
                              getter: (Player p) => p.name)
                        ],
                        threshold: 0.8,
                      ),
                    );
                    return fuse
                        .search(textEditingValue.text)
                        .map((r) => r.item);
                  });
            },
            onSelected: (Player selection) async {
              final db = ref.read(databaseProvider);
              final phones = await db.getPhoneNumbers(selection.playerID);
              setState(() {
                _selectedPlayer = selection;
                _nameController.text = selection.name;
                _ageController.text = selection.age.toString();
                _phoneControllers.clear();
                if (phones.isEmpty) {
                  _phoneControllers.add(TextEditingController());
                } else {
                  _phoneControllers.addAll(
                      phones.map((p) => TextEditingController(text: p)));
                }
              });
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                readOnly: _selectedPlayer != null,
                onChanged: (value) {
                  if (_selectedPlayer == null) _nameController.text = value;
                },
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Search or Enter Player Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: _selectedPlayer != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            _resetForm();
                          },
                        )
                      : null,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a name' : null,
              );
            },
            displayStringForOption: (Player option) =>
                '${option.name} (${option.age})',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _ageController,
            readOnly: _selectedPlayer != null,
            decoration: InputDecoration(
              labelText: 'Age',
              hintText: 'Enter player age',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter an age';
              if ((int.tryParse(v) ?? 0) <= 0) {
                return 'Please enter a valid age';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  MyCard _buildPhoneNumbersCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phone Numbers', style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 16),
          for (int i = 0; i < _phoneControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneControllers[i],
                      readOnly: _selectedPlayer != null,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        return null;
                      },
                    ),
                  ),
                  if (_phoneControllers.length <= 5) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(
                          () => _phoneControllers.add(TextEditingController())),
                    )
                  ],
                  if (_phoneControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () =>
                          setState(() => _phoneControllers.removeAt(i)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  MyCard _buildSubscriptionDetailsCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscription Details', style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 24),
          TextFormField(
            controller: _hoursController,
            decoration: InputDecoration(
              labelText: 'Subscription Duration (Hours)',
              hintText: 'e.g., 10, 20, 50',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter number of hours';
              if ((int.tryParse(v) ?? 0) <= 0) {
                return 'Number of hours must be positive';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _discountController,
            decoration: InputDecoration(
              labelText: 'Discount (%)',
              hintText: 'Enter discount percentage',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a discount';
              final d = int.tryParse(v) ?? -1;
              if (d < 0 || d > 100) return 'Discount must be between 0 and 100';
              return null;
            },
          ),
        ],
      ),
    );
  }

  MyCard _buildPaymentSummaryCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Payment Summary', style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              children: [
                Text('Total Fee', style: AppTextStyles.amountTextStyle),
                const SizedBox(height: 8),
                Text(
                  '${formatter.format(_totalFee)} SYP',
                  style: AppTextStyles.amountTextStyle.copyWith(fontSize: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _amountPaidController,
            decoration: InputDecoration(
              labelText: 'Amount Paid',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixText: 'SYP  ',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter amount paid';
              if ((int.tryParse(v) ?? -1) < 0) {
                return 'Amount cannot be negative';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _totalFee <= 0 ? null : _handleAddSubscription,
              child: const Text("Add Subscription"),
            ),
          ),
        ],
      ),
    );
  }
}
