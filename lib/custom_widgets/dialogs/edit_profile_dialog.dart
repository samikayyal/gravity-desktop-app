import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final String playerId;

  const EditProfileDialog({super.key, required this.playerId});

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final List<TextEditingController> _phoneControllers = [
    TextEditingController()
  ];

  @override
  Widget build(BuildContext context) {
    return ref.watch(pastPlayersProvider).when(
          loading: () =>
              MyDialog(child: const Center(child: CircularProgressIndicator())),
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

            return MyDialog(
                width: MediaQuery.of(context).size.width * 0.3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Edit ${player.name}'s Profile",
                      style: AppTextStyles.sectionHeaderStyle,
                    ),
                    const SizedBox(height: 20),
                    Form()
                  ],
                ));
          },
        );
  }
}
