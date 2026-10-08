import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../provider/authentication_provider.dart';
import 'fab.dart';

class EmailPasswordDialog extends StatefulWidget {
  const new({super.key});

  @override
  State<EmailPasswordDialog> createState() => _EmailPasswordDialogState();
}

class _EmailPasswordDialogState extends State<EmailPasswordDialog> {
  // Controllers for the text fields
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool visibleFirstPassword = false;
  bool visibleSecondPassword = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email and Password')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: .emailAddress,
                controller: _emailController,
              ),
              standardGap(),
              _buildPasswordField(
                _passwordController,
                'Passwort eingeben',
                visibleFirstPassword,
                () {
                  setState(() {
                    visibleFirstPassword = !visibleFirstPassword;
                  });
                },
              ),
              standardGap(),
              _buildPasswordField(
                _confirmPasswordController,
                'Passwort bestätigen',
                visibleSecondPassword,
                () {
                  setState(() {
                    visibleSecondPassword = !visibleSecondPassword;
                  });
                },
              ),
              buildFABGap(),
            ],
          ),
        ),
      ),
      floatingActionButton: ExtendedFAB(
        active: true,
        onClick: _submitForm,
        icon: Icons.login,
        label: 'Anlegen',
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Process the form data
      final email = _emailController.text;
      final password = _passwordController.text;

      AuthenticationProvider provider = context.read();
      await provider
          .linkEmailAndPassword(email, password)
          .then(
            (_) {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            onError: (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fehler beim Anlegen der Anmeldedaten: $e'),
                  ),
                );
              }
            },
          );
    }
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String labelText,
    bool visible,
    VoidCallback toggleVisibility,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
          onPressed: toggleVisibility,
        ),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (_passwordController.text != _confirmPasswordController.text) {
          return 'Passwörter stimmen nicht überein';
        }
        return null;
      },
    );
  }
}
