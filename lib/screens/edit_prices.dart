import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
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
          body: Center(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Price for 1 hour',
                            hintText: 'Enter price for 1 hour',
                          ),
                          keyboardType: TextInputType.number,
                          controller: hourPriceController,
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
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Price for 30 minutes',
                            hintText: 'Enter price for 30 minutes',
                          ),
                          keyboardType: TextInputType.number,
                          controller: halfHourPriceController,
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
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Price for additional hour',
                            hintText: 'Enter price for additional hour',
                          ),
                          keyboardType: TextInputType.number,
                          controller: additionalHourPriceController,
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
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Price for additional 30 minutes',
                            hintText: 'Enter price for additional 30 minutes',
                          ),
                          keyboardType: TextInputType.number,
                          controller: additionalHalfHourPriceController,
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
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final dbHelper = ref.read(databaseProvider);
                        try {
                          await dbHelper.updatePrices({
                            TimeSlice.hour: int.parse(hourPriceController.text),
                            TimeSlice.halfHour:
                                int.parse(halfHourPriceController.text),
                            TimeSlice.additionalHour:
                                int.parse(additionalHourPriceController.text),
                            TimeSlice.additionalHalfHour: int.parse(
                                additionalHalfHourPriceController.text),
                          });
                          
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Prices updated successfully')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error updating prices: $e')),
                          );
                        }
                        ref.invalidate(pricesProvider); // Refresh the prices
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save Prices'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      error: (err, stack) {
        return Scaffold(
          appBar: const MyAppBar(),
          body: Center(
            child: Text('Error: $err'),
          ),
        );
      },
      loading: () {
        return Scaffold(
          appBar: const MyAppBar(),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
