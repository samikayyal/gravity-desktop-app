import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_card.dart';
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

  @override
  void initState() {
    _loadPlayerPhones();
    super.initState();
  }

  Future<void> _loadPlayerPhones() async {
    setState(() {
      isLoading = true;
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

                // Fill info for the player
                _nameController.text = player.name;
                _ageController.text = player.age.toString();
                _phoneControllers.clear();
                _phoneControllers.addAll(_phoneNumbers
                    .map((phone) => TextEditingController(text: phone))
                    .toList());

                return MyDialog(
                    // width: 400.0, // Explicit width for better control
                    child: MyCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Edit ${player.name}'s Profile",
                        style: AppTextStyles.sectionHeaderStyle,
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                            spacing: 6,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                style: AppTextStyles.regularTextStyle,
                                controller: _nameController,
                                decoration: InputDecoration(
                                    labelText: 'Name',
                                    labelStyle: AppTextStyles.regularTextStyle,
                                    hintText: 'Enter name',
                                    hintStyle: AppTextStyles.subtitleTextStyle,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 18),
                                    prefixIcon: Icon(Icons.person,
                                        color: Colors.grey.shade600, size: 20)),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _ageController,
                                decoration: InputDecoration(
                                    labelText: 'Age',
                                    labelStyle: AppTextStyles.regularTextStyle,
                                    hintText: 'Enter age',
                                    hintStyle: AppTextStyles.subtitleTextStyle,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 18),
                                    prefixIcon: Icon(Icons.numbers,
                                        color: Colors.grey.shade600, size: 20)),
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
                              const SizedBox(height: 10),
                              for (int i = 0; i < _phoneControllers.length; i++)
                                TextFormField(
                                  controller: _phoneControllers[i],
                                  decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      labelStyle:
                                          AppTextStyles.regularTextStyle,
                                      hintText: 'Enter phone number #${i + 1}',
                                      hintStyle:
                                          AppTextStyles.subtitleTextStyle,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 18),
                                      prefixIcon: Icon(Icons.phone,
                                          color: Colors.grey.shade600,
                                          size: 20)),
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
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
                            ]),
                      ),
                      const SizedBox(height: 10),
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
                                style: AppTextStyles.secondaryButtonTextStyle,
                              )),
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
                                          age: int.parse(_ageController.text),
                                          phones: _phoneControllers
                                              .map((c) => c.text.trim())
                                              .toList());
                                  await ref
                                      .read(subscriptionsProvider.notifier)
                                      .refresh();
                                  if (context.mounted) {
                                    MyMaterialBanner.showFloatingBanner(context,
                                        message:
                                            "Player profile updated successfully",
                                        type: MessageType.success);
                                    Navigator.of(context).pop();
                                  }
                                } catch (e, stackTrace) {
                                  if (context.mounted) {
                                    log("Error editing player profile: $e \n $stackTrace");
                                    MyMaterialBanner.showFloatingBanner(context,
                                        message: "Could not edit player: $e",
                                        type: MessageType.error);
                                  }
                                }
                              },
                              style: AppButtonStyles.primaryButton,
                              child: Text(
                                "Save",
                                style: AppTextStyles.primaryButtonTextStyle,
                              ))
                        ],
                      )
                    ],
                  ),
                ));
              },
            );
  }
}
