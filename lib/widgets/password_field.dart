import 'package:flutter/material.dart';

/// A widget for entering a password.
///
/// It provides a text field with an icon and a toggle to show or hide the password.
class UserPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool disabled;

  final String labelText = 'Geheimer Schlüssel';
  final IconData prefixIcon = Icons.lock_outline;

  const UserPasswordField({
    super.key,
    required this.controller,
    this.disabled = false,
    this.validator,
  });

  @override
  State<UserPasswordField> createState() => _UserPasswordFieldState();
}

class _UserPasswordFieldState extends State<UserPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enabled: !widget.disabled,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
          onPressed: widget.disabled
              ? null
              : () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
        ),
      ),
      validator: widget.validator,
    );
  }
}
