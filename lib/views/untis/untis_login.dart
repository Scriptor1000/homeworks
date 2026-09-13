import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/config_provider.dart';
import '../../provider/credential_provider.dart';
import '../../database/models/credentials.dart';
import '../../utilities/common.dart';
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

  /// Controllers for user text input.
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();
  final _serverController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    /// Dispose controllers to prevent memory leaks
    _usernameController.dispose();
    _passwordController.dispose();
    _schoolController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  void initState() {
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

    /// Mark login as loading
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

    _usernameController.text = provider.credentials?.username ?? '';
    _passwordController.text = provider.credentials?.password ?? '';
    _schoolController.text =
        provider.credentials?.school ?? 'albert-schweitzer';
    _serverController.text =
        provider.credentials?.server ?? 'albert-schweitzer.webuntis.com';
    return Scaffold(
      appBar: AppBar(title: const Text('Untis Anmeldung')),
      body: withConstrainedWidth(
        context,
        child: Column(
          children: [
            /// Top progress indicator (also driven by override checkbox)
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

                      /// Form fields for credentials
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
                      standardGap(),
                      _buildDemoModeToggle(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      /// Button for submitting the form & saving credentials locally
      floatingActionButton: ExtendedFAB(
        onClick: submit,
        active: !_isLoading,
        icon: Icons.login,
        label: 'Anmelden & lokal speichern',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDemoModeToggle() {
    final provider = context.watch<ConfigProvider>();
    return SwitchListTile(
      title: const Text('Demo-Modus aktivieren'),
      value: provider.untisDemoMode,
      onChanged: (value) async {
        if (value == false) {
          provider.untisDemoMode = false;
        } else if (await _showDemoModeInfoDialog() && mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Future<bool> _showDemoModeInfoDialog() async {
    return await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Demo-Modus'),
              content: const Text(
                'Im Demo-Modus werden keine echten Untis Anmeldedaten benötigt. '
                'Die App zeigt stattdessen eine Demo-Version der Untis-Funktionen, '
                'wofür konstante Unterrichtsdaten verwendet werden. '
                'Diese Option ist für etwaige Reviews von Apple gedacht.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<ConfigProvider>().untisDemoMode = true;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Aktiveren'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
