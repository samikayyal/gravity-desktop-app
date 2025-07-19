import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool isDisabled;
  final bool readOnly;
  final bool isNumberInputOnly;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? suffixText;
  final String? prefixText;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final void Function(String)? onFieldSubmitted;
  final double borderRadius;

  const MyTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.isDisabled = false,
    this.readOnly = false,
    this.isNumberInputOnly = false,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.suffixText,
    this.prefixText,
    this.onChanged,
    this.focusNode,
    this.onFieldSubmitted,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFieldDisabled = isDisabled || readOnly;

    return TextFormField(
      controller: controller,
      enabled: !isDisabled,
      readOnly: readOnly,
      focusNode: focusNode,
      style: AppTextStyles.regularTextStyle,
      decoration: InputDecoration(
        filled: true,
        fillColor: isFieldDisabled ? Colors.grey.shade100 : Colors.white,
        labelText: readOnly ? "$labelText (Locked)" : labelText,
        labelStyle: AppTextStyles.regularTextStyle.copyWith(
          color: isFieldDisabled ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
        hintText: hintText,
        hintStyle: AppTextStyles.subtitleTextStyle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: readOnly && prefixIcon == null
            ? Icon(
                Icons.lock_outline,
                color: Colors.grey.shade400,
                size: 20,
              )
            : prefixIcon,
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        prefixStyle: prefixText != null
            ? AppTextStyles.regularTextStyle.copyWith(color: Colors.black)
            : null,
        suffixText: suffixText,
        suffixStyle: suffixText != null
            ? AppTextStyles.regularTextStyle.copyWith(color: Colors.black)
            : null,
      ),
      keyboardType:
          isNumberInputOnly ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isNumberInputOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
