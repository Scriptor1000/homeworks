import 'package:flutter/material.dart';

import '../database/models/credentials.dart';
import 'fab.dart';

/// Enum für die verschiedenen Arten von Anmeldefeldern
enum CredentialFieldType { username, password, school, server }

/// A widget for entering Untis credentials.
/// It provides a form with fields for username, password, school, and server.
/// Can also be used to display the credentials in a read-only mode.
class CredentialForm extends StatefulWidget {
  const CredentialForm({
    super.key,
    this.usernameController,
    this.passwordController,
    this.schoolController,
    this.serverController,
    this.formKey,
    this.initialCredentials,
    this.disabled = false,
  });

  final GlobalKey<FormState>? formKey;
  final TextEditingController? usernameController;
  final TextEditingController? passwordController;
  final TextEditingController? schoolController;
  final TextEditingController? serverController;
  final UntisCredentials? initialCredentials;
  final bool disabled;

  @override
  State<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<CredentialForm> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildTextFormField(
            CredentialFieldType.username,
            widget.usernameController,
          ),
          standardGap(),
          buildTextFormField(
            CredentialFieldType.password,
            widget.passwordController,
          ),
          standardGap(),
          buildTextFormField(
            CredentialFieldType.school,
            widget.schoolController,
          ),
          standardGap(),
          buildTextFormField(
            CredentialFieldType.server,
            widget.serverController,
          ),
        ],
      ),
    );
  }

  Widget buildTextFormField(
    CredentialFieldType fieldType,
    TextEditingController? controller,
  ) {
    String labelText;
    IconData icon;
    bool obscureText = false;
    String? initialValue;

    switch (fieldType) {
      case CredentialFieldType.username:
        labelText = 'Benutzername';
        icon = Icons.person_outline;
        initialValue = widget.initialCredentials?.username;
        break;
      case CredentialFieldType.password:
        labelText = 'Passwort';
        icon = Icons.lock_outline;
        obscureText = !_showPassword;
        initialValue = widget.initialCredentials?.password;
        break;
      case CredentialFieldType.school:
        labelText = 'Schule';
        icon = Icons.school_outlined;
        initialValue = widget.initialCredentials?.school;
        break;
      case CredentialFieldType.server:
        labelText = 'Server';
        icon = Icons.dns_outlined;
        initialValue = widget.initialCredentials?.server;
        break;
    }

    return TextFormField(
      enabled: !widget.disabled,
      obscureText: fieldType == CredentialFieldType.password && obscureText,
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        suffixIcon: fieldType == CredentialFieldType.password
            ? IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bitte $labelText eingeben';
        }
        return null;
      },
    );
  }
}
