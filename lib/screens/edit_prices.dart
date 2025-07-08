import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';

class EditPricesScreen extends ConsumerStatefulWidget {
  const EditPricesScreen({super.key});

  @override
  ConsumerState<EditPricesScreen> createState() => _EditPricesScreenState();
}

class _EditPricesScreenState extends ConsumerState<EditPricesScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController hourPriceController;
  late final TextEditingController halfHourPriceController;
  late final TextEditingController additionalHourPriceController;
  late final TextEditingController additionalHalfHourPriceController;

  @override
  void initState() {
    super.initState();
    hourPriceController = TextEditingController();
    halfHourPriceController = TextEditingController();
    additionalHourPriceController = TextEditingController();
    additionalHalfHourPriceController = TextEditingController();
  }

  @override
  void dispose() {
    hourPriceController.dispose();
    halfHourPriceController.dispose();
    additionalHourPriceController.dispose();
    additionalHalfHourPriceController.dispose();
    super.dispose();
  }

  Widget _buildPriceField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.sectionHeaderStyle),
                  Text(subtitle, style: AppTextStyles.subtitleTextStyle),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: AppTextStyles.regularTextStyle,
            decoration: InputDecoration(
              prefixText: 'SYP   ',
              prefixStyle: AppTextStyles.subtitleTextStyle,
              hintText: 'Enter amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.indigo[600]!, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a price';
              }
              final price = int.tryParse(value);
              if (price == null || price < 0) {
                return 'Please enter a valid price';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previousPricesAsync = ref.watch(pricesProvider);
    return previousPricesAsync.when(
      data: (previousPrices) {
        // Set controller values from previousPrices if not already set
        hourPriceController.text = previousPrices[TimeSlice.hour].toString();
        halfHourPriceController.text =
            previousPrices[TimeSlice.halfHour].toString();
        additionalHourPriceController.text =
            previousPrices[TimeSlice.additionalHour].toString();
        additionalHalfHourPriceController.text =
            previousPrices[TimeSlice.additionalHalfHour].toString();
        return Scaffold(
          appBar: const MyAppBar(),
          backgroundColor: Colors.grey[50],
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Price form
                    Card(
                      elevation: 2,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildPriceField(
                                controller: hourPriceController,
                                icon: Icons.schedule,
                                label: 'Standard Hour Rate',
                                subtitle: 'Base price for first hour of play',
                              ),
                              const SizedBox(height: 24),
                              _buildPriceField(
                                controller: halfHourPriceController,
                                icon: Icons.timer,
                                label: '30 Minutes Rate',
                                subtitle: 'Base price for 30-minute sessions',
                              ),
                              const SizedBox(height: 24),
                              _buildPriceField(
                                controller: additionalHourPriceController,
                                icon: Icons.add_circle_outline,
                                label: 'Additional Hour Rate',
                                subtitle: 'Price for each additional hour',
                              ),
                              const SizedBox(height: 24),
                              _buildPriceField(
                                controller: additionalHalfHourPriceController,
                                icon: Icons.more_time,
                                label: 'Additional 30 Minutes Rate',
                                subtitle:
                                    'Price for each additional 30 minutes',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: AppButtonStyles.secondaryButton,
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.secondaryButtonTextStyle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: AppButtonStyles.primaryButton,
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final dbHelper = ref.read(databaseProvider);
                              try {
                                await dbHelper.updatePrices({
                                  TimeSlice.hour:
                                      int.parse(hourPriceController.text),
                                  TimeSlice.halfHour:
                                      int.parse(halfHourPriceController.text),
                                  TimeSlice.additionalHour: int.parse(
                                      additionalHourPriceController.text),
                                  TimeSlice.additionalHalfHour: int.parse(
                                      additionalHalfHourPriceController.text),
                                });

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Prices updated successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green[600],
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                'Error updating prices: $e')),
                                      ],
                                    ),
                                    backgroundColor: Colors.red[600],
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              ref.invalidate(
                                  pricesProvider); // Refresh the prices
                              Navigator.pop(context);
                            }
                          },
                          child: Text('Save Changes',
                              style: AppTextStyles.primaryButtonTextStyle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      error: (err, stack) {
        return Scaffold(
          appBar: const MyAppBar(),
          backgroundColor: Colors.grey[50],
          body: Center(
            child: Card(
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Prices',
                      style: AppTextStyles.pageTitleStyle
                          .copyWith(color: Colors.red[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      style: AppTextStyles.subtitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: AppButtonStyles.primaryButton,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () {
        return Scaffold(
          appBar: const MyAppBar(),
          backgroundColor: Colors.grey[50],
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading pricing information...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
