import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../utilities/enums.dart';
import '../../utilities/global_snackbar.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
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
    // User forgot password
    if (_userPasswordController.text.isEmpty) {
      showSnackBar('Bitte gib dein Benutzerpasswort ein');
      return;
    }

    // UI: show loading
    setState(() {
      _isLoading = true;
    });

    // Ask provider to load + decrypt credentials
    context
        .read<CredentialProvider>()
        .loadCredentialsOnline(_userPasswordController.text)
        .then((_) {
      if (mounted) {
        context.pop();
      }
    }).onError((error, stackTrace) {
      setState(() {
        showSnackBar('Fehler: $error');
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to provider updates
    var credentialProvider = context.watch<CredentialProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gespeicherte Anmeldedaten laden'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar (at top)
            OwnProgressIndicator(
              active: _isLoading ||
                  credentialProvider.sessionState == UntisSessionState.loading,
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
                      buildFABGap()
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom button:
      // - If currently loading → disabled “sync” button
      // - Otherwise → load credentials
      floatingActionButton:
          credentialProvider.sessionState == UntisSessionState.loading
              ? ExtendedFAB(
                  onClick: () {},
                  active: false,
                  icon: Icons.sync,
                  label: 'Verbinde mit Untis',
                )
              : ExtendedFAB(
                  onClick: _loadCredentials,
                  active: !_isLoading,
                  icon: Icons.cloud_download_outlined,
                  label: 'Anmeldedaten laden'),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
