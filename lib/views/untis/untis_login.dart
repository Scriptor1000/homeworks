import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../database/models/credentials.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
import '../../widgets/info_box.dart';
import '../../widgets/own_progress_indicator.dart';

/// The UI state for logging in to Untis.
enum LoginState { none, loading, success }

/// A widget for logging into Untis and creating a session.
///
/// The user enters credentials (username, password, school, server),
/// which are passed to [CredentialProvider].
/// If login succeeds → credentials are stored locally and
/// the screen is closed.
class UntisLogin extends StatefulWidget {
  const UntisLogin({super.key});

  @override
  State<UntisLogin> createState() => _UntisLoginState();
}

class _UntisLoginState extends State<UntisLogin> {
  /// Tracks the current authentication state.
  LoginState _loginState = LoginState.none;

  /// Will hold the new credentials after form submission.
  UntisCredentials? _credentials;

  /// Form key for validating the credential form.
  final _formKey = GlobalKey<FormState>();

  /// Controllers for user text input.
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();
  final _serverController = TextEditingController();

  /// A checkbox UI flag (used for testing / manual override of indicator)
  bool value = false;

  @override
  void initState() {
    /// Pre-fill example/preferred values
    _schoolController.text = 'Albert Schweitzer';
    _serverController.text = 'hektor.webuntis.com';
    super.initState();
  }

  @override
  void dispose() {
    /// Dispose controllers to prevent memory leaks
    _usernameController.dispose();
    _passwordController.dispose();
    _schoolController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  /// Validates the input → builds [UntisCredentials] → stores them via
  /// [CredentialProvider].
  ///
  /// On success → screen is closed.
  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    /// Build credentials from input
    _credentials = UntisCredentials(
      username: _usernameController.text,
      school: _schoolController.text,
      password: _passwordController.text,
      server: _serverController.text,
    );

    /// Mark login as loading
    setState(() {
      _loginState = LoginState.loading;
    });

    try {
      /// Attempt storing credentials & creating session
      await context.read<CredentialProvider>().setCredentials(_credentials!);

      // TODO maybe straight to upload or import?

      /// Close screen if still mounted
      if (mounted) {
        context.pop();
      }
    } on Exception {
      /// On failure → reset state
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
          /// Top progress indicator (also driven by override checkbox)
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

                    /// Form fields for credentials
                    CredentialForm(
                      formKey: _formKey,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      schoolController: _schoolController,
                      serverController: _serverController,
                    ),

                    standardGap(),

                    /// Explanatory info box about storage behavior
                    const InfoBox(
                      paragraphs: [
                        'Die Anmeldedaten werden lokal gespeichert und '
                            'können später für die Synchronisation mit der '
                            'Cloud verwendet werden.'
                      ],
                      title: 'Hinweis',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      /// Button for submitting the form & saving credentials locally
      floatingActionButton: ExtendedFAB(
        onClick: submit,
        active: _loginState == LoginState.none,
        icon: Icons.login,
        label: 'Session erstellen und lokal speichern',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// A checkbox to force-enable the progress indicator.
  ///
  /// (Seems to be experimental / debug UI)
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
      },
    );
  }
}
