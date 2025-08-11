import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../database/models/credentials.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
import '../../widgets/info_box.dart';
import '../../widgets/own_progress_indicator.dart';

enum LoginState { none, loading, success }

/// A widget for logging into Untis and creating a session.
///
/// The user can enter their Untis credentials, which are then used to create a session.
/// If the session is created successfully, the credentials are given to the [CredentialProvider] and stored locally.
class UntisLogin extends StatefulWidget {
  const UntisLogin({super.key});

  @override
  State<UntisLogin> createState() => _UntisLoginState();
}

class _UntisLoginState extends State<UntisLogin> {
  LoginState _loginState = LoginState.none;
  UntisCredentials? _credentials;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();
  final _serverController = TextEditingController();

  bool value = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _schoolController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _schoolController.text = 'Albert Schweitzer';
    _serverController.text = 'hektor.webuntis.com';

    super.initState();
  }

  void submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _credentials = UntisCredentials(
      username: _usernameController.text,
      school: _schoolController.text,
      password: _passwordController.text,
      server: _serverController.text,
    );

    setState(() {
      _loginState = LoginState.loading;
    });
    try {
      await context.read<CredentialProvider>().setCredentials(_credentials!);

      // TODO maybe straight to upload or import?
      if (mounted) {
        context.pop();
      }
    } on Exception {
      setState(() {
        _loginState = LoginState.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Column(
        children: [
          OwnProgressIndicator(
            active: _loginState == LoginState.loading || value,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'Gebe deine Anmeldedaten für Untis ein.',
                      style: TextStyle(fontSize: 16),
                    ),
                    standardGap(),
                    CredentialForm(
                      formKey: _formKey,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      schoolController: _schoolController,
                      serverController: _serverController,
                    ),
                    standardGap(),
                    const InfoBox(paragraphs: [
                      'Die Anmeldedaten werden lokal gespeichert und '
                          'können später für die Synchronisation mit der '
                          'Cloud verwendet werden.'
                    ], title: 'Hinweis'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ExtendedFAB(
          onClick: submit,
          active: _loginState == LoginState.none,
          icon: Icons.login,
          label: 'Session erstellen und lokal speichern'),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget buildCheckBox() {
    return CheckboxListTile(
        title: const Text('Progress Indicator überschreiben'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        value: value,
        onChanged: (bool? newValue) {
          setState(() {
            value = newValue!;
          });
        });
  }
}
