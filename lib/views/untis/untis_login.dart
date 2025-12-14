import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../database/models/credentials.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
import '../../widgets/info_box.dart';
import '../../widgets/own_progress_indicator.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();
  final _serverController = TextEditingController();

  bool _isLoading = false;

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
    final provider = context.read<CredentialProvider>();
    _usernameController.text = provider.credentials?.username ?? '';
    _passwordController.text = provider.credentials?.password ?? '';
    _schoolController.text =
        provider.credentials?.school ?? 'albert-schweitzer';
    _serverController.text =
        provider.credentials?.server ?? 'albert-schweitzer.webuntis.com';

    super.initState();
  }

  void submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final credentials = UntisCredentials(
      username: _usernameController.text,
      school: _schoolController.text,
      password: _passwordController.text,
      server: _serverController.text,
    );

    setState(() {
      _isLoading = true;
    });
    final provider = context.read<CredentialProvider>();
    await provider
        .setCredentials(credentials)
        .then(
          (_) {
            if (mounted) {
              context.pop();
            }
          },
          onError: (error, _) {
            setState(() {
              showSnackBar('Fehler: $error');
              _isLoading = false;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CredentialProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Untis Anmeldung')),
      body: Column(
        children: [
          OwnProgressIndicator(
            active: _isLoading,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (provider.sessionStatus == .sessionAccomplished)
                      InfoBox(
                        paragraphs: [
                          'Du hast bereits gültige Anmeldedaten für Untis angegeben.',
                          'Wenn du fortfährst, werden deine vorhandenen Anmeldedaten unwiderruflich überschrieben.',
                        ],
                        title: 'Achtung',
                        icon: Icons.warning,
                        accentColor: Colors.orange,
                      ),
                    if (provider.sessionStatus == .sessionAccomplished)
                      standardGap(),
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
                    const InfoBox(
                      paragraphs: [
                        'Die Anmeldedaten werden lokal gespeichert und '
                            'können später für die Synchronisation mit der '
                            'Cloud verwendet werden.',
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
      floatingActionButton: ExtendedFAB(
        onClick: submit,
        active: !_isLoading,
        icon: Icons.login,
        label: 'Anmelden & lokal speichern',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
