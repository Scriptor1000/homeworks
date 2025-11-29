import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../utilities/enums.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
import '../../widgets/info_box.dart';
import '../../widgets/own_progress_indicator.dart';
import '../../widgets/password_field.dart';

/// A widget for loading Untis credentials from Firestore.
///
/// The user can enter their user password wich is used to decrypt the stored credentials.
/// If the credentials are found, they are given to [CredentialProvider] and stored locally.
class LoadCredentials extends StatefulWidget {
  const LoadCredentials({super.key});

  @override
  State<LoadCredentials> createState() => _LoadCredentialsState();
}

class _LoadCredentialsState extends State<LoadCredentials> {
  final _userPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _userPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    if (_isLoading) return;
    if (_userPasswordController.text.isEmpty) {
      showSnackBar('Bitte gib dein Benutzerpasswort ein');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    context
        .read<CredentialProvider>()
        .loadCredentialsOnline(_userPasswordController.text)
        .then(
          (_) {
            if (mounted) {
              context.pop();
            }
          },
          onError: (error, stackTrace) {
            setState(() {
              showSnackBar('Fehler: $error');
              _isLoading = false;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final credentialProvider = context.watch<CredentialProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Gespeicherte Anmeldedaten laden')),
      body: SafeArea(
        child: Column(
          children: [
            OwnProgressIndicator(
              active: _isLoading,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),

            // Hauptcontent mit ScrollView
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (credentialProvider.hasCredentials)
                        InfoBox(
                          title: 'Achtung!',
                          paragraphs: [
                            'Es sind bereits Anmeldedaten auf diesem Gerät gespeichert. Durch das Herunterladen der Clouddaten werden diese unwiderruflich überschrieben.',
                            if (credentialProvider.sessionStatus ==
                                UntisSessionStatus.sessionAccomplished)
                              'Mit den lokalen Anmeldedaten wurde bereits erfolgreich eine Verbindung zu Untis hergestellt.',
                          ],
                          icon: Icons.warning,
                          accentColor: Colors.orange,
                        ),

                      if (credentialProvider.hasCredentials) standardGap(),
                      // Erklärungstext
                      const Text(
                        'Gib dein Benutzerpasswort ein, um deine gespeicherten Untis-Anmeldedaten zu laden.',
                        style: TextStyle(fontSize: 16),
                      ),
                      standardGap(),

                      // Benutzerpasswort-Feld mit dem neuen PasswordField-Widget
                      UserPasswordField(
                        controller: _userPasswordController,
                        disabled: _isLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte gib dein Benutzerpasswort ein';
                          }
                          return null;
                        },
                      ),
                      standardGap(),

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CredentialForm(
                          initialCredentials: credentialProvider.credentials,
                          disabled: true,
                        ),
                      ),
                      buildFABGap(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ExtendedFAB(
        onClick: _loadCredentials,
        active: true,
        icon: Icons.sync,
        label: 'Anmeldedaten importieren',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
