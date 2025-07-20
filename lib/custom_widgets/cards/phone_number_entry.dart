import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text_field.dart';

class PhoneNumberEntryCard extends ConsumerStatefulWidget {
  final String title;
  final List<TextEditingController> controllers;
  final bool isDisabled;
  final bool disableListModification;

  final VoidCallback addOnPressed;
  final void Function(int index) removeOnPressed;
  const PhoneNumberEntryCard(
      {super.key,
      required this.controllers,
      required this.addOnPressed,
      required this.removeOnPressed,
      this.title = 'Phone Numbers',
      this.isDisabled = false,
      this.disableListModification = false});

  @override
  ConsumerState<PhoneNumberEntryCard> createState() =>
      _PhoneNumberEntryCardState();
}

class _PhoneNumberEntryCardState extends ConsumerState<PhoneNumberEntryCard> {
  @override
  Widget build(BuildContext context) {
    return MyCard(
        child: Column(
      children: [
        Text(
          widget.title,
          style: AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < widget.controllers.length; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: MyTextField(
                    controller: widget.controllers[i],
                    labelText: "Phone Number #$i",
                    hintText: "Enter a phone number (starting with 09)",
                    isNumberInputOnly: true,
                    isDisabled: widget.isDisabled,
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
                if (i == widget.controllers.length - 1 &&
                    !widget.disableListModification)
                  IconButton(
                    icon: const Icon(Icons.add, size: 28),
                    tooltip: 'Add phone number',
                    onPressed: widget.addOnPressed,
                  ),
                if (widget.controllers.length > 1 &&
                    !widget.disableListModification) ...[
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.remove, size: 28),
                      tooltip: 'Remove phone number',
                      onPressed: () => widget.removeOnPressed(i))
                ]
              ],
            ),
          )
      ],
    ));
  }
}
