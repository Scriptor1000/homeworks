import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../utilities/common.dart';
import '../../utilities/enums.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
import '../../widgets/info_box.dart';
import '../../widgets/own_progress_indicator.dart';
import '../../widgets/password_field.dart';

/// Screen used to load Untis credentials stored in Firestore.
///
/// The user enters their **user password**, which is used locally to:
/// - decrypt encrypted credentials retrieved from Firestore
/// - then pass them to [CredentialProvider] to store locally
///
/// If loading succeeds → screen automatically closes.
class LoadCredentials extends StatefulWidget {
  const LoadCredentials({super.key});

  @override
  State<LoadCredentials> createState() => _LoadCredentialsState();
}

class _LoadCredentialsState extends State<LoadCredentials> {
  /// Controller for password text field
  final _userPasswordController = TextEditingController();

  /// UI flag: when true, UI shows loading indicators and disables fields
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

  /// Triggers loading of credentials from Firestore
  ///
  /// Steps:
  /// 1. Check password not empty
  /// 2. Show loading
  /// 3. Ask [CredentialProvider] to load + decrypt credentials
  /// 4. Stop loading or show error
  Future<void> _loadCredentials() async {
    if (_isLoading) return;

    /// User forgot password
    if (_userPasswordController.text.isEmpty) {
      showSnackBar('Bitte gib dein Benutzerpasswort ein');
      return;
    }

    /// UI: show loading
    setState(() {
      _isLoading = true;
    });

    /// Ask provider to load + decrypt credentials
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
    /// Subscribe to provider updates
    final credentialProvider = context.watch<CredentialProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Gespeicherte Anmeldedaten laden')),
      body: withConstrainedWidth(
        context,
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar (at top)
              OwnProgressIndicator(
                active:
                    _isLoading ||
                    credentialProvider.sessionStatus ==
                        UntisSessionStatus.loading,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),

              // Main content below progress indicator
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Text explaining purpose
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

                        /// Password input
                        /// (the password is never sent to server — only used locally to decrypt)
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
                        Row(
                          mainAxisAlignment: .start,
                          mainAxisSize: .min,
                          children: [
                            TextButton.icon(
                              onPressed: buildForgotPasswordDialog,
                              icon: const Icon(Icons.help_outline),
                              label: const Text('Passwort vergessen?'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        standardGap(),

                        /// Shows stored credentials (already decrypted if available)
                        /// but disabled — cannot edit here
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

  Future<void> buildForgotPasswordDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Passwort vergessen'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: const Text(
              'Wenn du dein Benutzerpasswort vergessen hast, können wir deine gespeicherten Anmeldedaten aufgrund der Verschlüsselung nicht wiederherstellen.\n'
              'Deine einzige Möglichkeit besteht darin, deine Anmeldedaten nochmal manuell einzugeben und anschließend erneut in die Cloud hochzuladen.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Schließen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
