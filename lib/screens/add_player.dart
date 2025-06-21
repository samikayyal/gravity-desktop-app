import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
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
  List<TextEditingController> phoneControllers = [];
  int hoursReserved = 0;
  int minutesReserved = 0;
  bool isOpenTime = false;

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
