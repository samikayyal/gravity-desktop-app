import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final String playerId;

  const EditProfileDialog({super.key, required this.playerId});

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final List<TextEditingController> _phoneControllers = [
    TextEditingController()
  ];

  List<String> _phoneNumbers = [];
  bool _controllersInitialized = false;

  @override
  void initState() {
    _loadPlayerPhones();
    super.initState();
  }

  void _addPhoneField() {
    setState(() {
      _phoneControllers.add(TextEditingController());
    });
  }

  void _removePhoneField(int index) {
    setState(() {
      if (_phoneControllers.length > 1) {
        _phoneControllers[index].dispose();
        _phoneControllers.removeAt(index);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlayerPhones() async {
    setState(() {
      isLoading = true;
      _controllersInitialized = false; // Reset initialization flag
    });

    _phoneNumbers = await ref
        .read(pastPlayersProvider.notifier)
        .getPhoneNumbers(widget.playerId);

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? MyDialog(child: const Center(child: CircularProgressIndicator()))
        : ref.watch(pastPlayersProvider).when(
              loading: () => MyDialog(
                  child: const Center(child: CircularProgressIndicator())),
              error: (error, stack) {
                log("Error in edit profile dialog: $error");
                return MyDialog(
                  child: Center(
                    child: Text('Error loading players: $error'),
                  ),
                );
              },
              data: (List<Player> players) {
                if (players.isEmpty ||
                    !players.map((p) => p.playerID).contains(widget.playerId)) {
                  return MyDialog(
                    child: Center(
                      child: Text('Player Not Found.'),
                    ),
                  );
                }

                final Player player =
                    players.firstWhere((p) => p.playerID == widget.playerId);

                // Initialize controllers only once per player load
                if (!_controllersInitialized) {
                  _nameController.text = player.name;
                  _ageController.text = player.age.toString();
                  _phoneControllers.clear();
                  if (_phoneNumbers.isNotEmpty) {
                    _phoneControllers.addAll(_phoneNumbers
                        .map((phone) => TextEditingController(text: phone))
                        .toList());
                  } else {
                    // Ensure at least one phone field is available
                    if (_phoneControllers.isEmpty) {
                      _phoneControllers.add(TextEditingController());
                    }
                  }
                  _controllersInitialized = true;
                }

                return MyDialog(
                    width: 450.0, // Better width for improved layout
                    child: MyCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: Theme.of(context).primaryColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Edit ${player.name}'s Profile",
                                    style: AppTextStyles.sectionHeaderStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Form(
                              key: _formKey,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Name Field
                                    TextFormField(
                                      style: AppTextStyles.regularTextStyle,
                                      controller: _nameController,
                                      decoration: InputDecoration(
                                          labelText: 'Name',
                                          labelStyle:
                                              AppTextStyles.regularTextStyle,
                                          hintText: 'Enter name',
                                          hintStyle:
                                              AppTextStyles.subtitleTextStyle,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 18),
                                          prefixIcon: Icon(Icons.person,
                                              color: Colors.grey.shade600,
                                              size: 20)),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Age Field
                                    TextFormField(
                                      controller: _ageController,
                                      decoration: InputDecoration(
                                          labelText: 'Age',
                                          labelStyle:
                                              AppTextStyles.regularTextStyle,
                                          hintText: 'Enter age',
                                          hintStyle:
                                              AppTextStyles.subtitleTextStyle,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 18),
                                          prefixIcon: Icon(Icons.numbers,
                                              color: Colors.grey.shade600,
                                              size: 20)),
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
                                    const SizedBox(height: 20),

                                    // Phone Numbers Section
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Phone Numbers',
                                          style: AppTextStyles.regularTextStyle
                                              .copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _addPhoneField,
                                          icon: const Icon(Icons.add_circle),
                                          color: Theme.of(context).primaryColor,
                                          tooltip: 'Add phone number',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Phone Number Fields
                                    for (int i = 0;
                                        i < _phoneControllers.length;
                                        i++)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller:
                                                    _phoneControllers[i],
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'Phone Number ${i + 1}',
                                                    labelStyle: AppTextStyles
                                                        .regularTextStyle,
                                                    hintText:
                                                        'Enter phone number',
                                                    hintStyle: AppTextStyles
                                                        .subtitleTextStyle,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 16,
                                                            vertical: 18),
                                                    prefixIcon: Icon(
                                                        Icons.phone,
                                                        color: Colors
                                                            .grey.shade600,
                                                        size: 20)),
                                                keyboardType:
                                                    TextInputType.phone,
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please enter a phone number';
                                                  }
                                                  if (!value.startsWith('09')) {
                                                    return 'Phone number must start with 09';
                                                  }
                                                  if (value.length != 10) {
                                                    return 'Phone number must be 10 digits';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (_phoneControllers.length > 1)
                                              IconButton(
                                                onPressed: () =>
                                                    _removePhoneField(i),
                                                icon: const Icon(
                                                    Icons.remove_circle),
                                                color: Colors.red,
                                                tooltip: 'Remove phone number',
                                              ),
                                          ],
                                        ),
                                      ),
                                  ]),
                            ),
                            const SizedBox(height: 24),
                            //
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(
                                      "Cancel",
                                      style: AppTextStyles
                                          .secondaryButtonTextStyle,
                                    )),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                    onPressed: () async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      try {
                                        await ref
                                            .read(pastPlayersProvider.notifier)
                                            .editPlayer(
                                                playerID: player.playerID,
                                                name: _nameController.text,
                                                age: int.parse(
                                                    _ageController.text),
                                                phones: _phoneControllers
                                                    .map((c) => c.text.trim())
                                                    .where((phone) =>
                                                        phone.isNotEmpty)
                                                    .toList());
                                        await ref
                                            .read(
                                                subscriptionsProvider.notifier)
                                            .refresh();

                                        await ref
                                            .read(pastPlayersProvider.notifier)
                                            .refresh();
                                        if (context.mounted) {
                                          MyMaterialBanner.showFloatingBanner(
                                              context,
                                              message:
                                                  "Player profile updated successfully",
                                              type: MessageType.success);
                                          Navigator.of(context).pop();
                                        }
                                      } catch (e, stackTrace) {
                                        if (context.mounted) {
                                          log("Error editing player profile: $e \n $stackTrace");
                                          MyMaterialBanner.showFloatingBanner(
                                              context,
                                              message:
                                                  "Could not edit player: $e",
                                              type: MessageType.error);
                                        }
                                      }
                                    },
                                    style: AppButtonStyles.primaryButton,
                                    child: Text(
                                      "Save Changes",
                                      style:
                                          AppTextStyles.primaryButtonTextStyle,
                                    ))
                              ],
                            )
                          ],
                        ),
                      ),
                    ));
              },
            );
  }
}
