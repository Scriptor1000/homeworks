import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/credential_provider.dart';
import '../../utilities/enums.dart';
import '../../widgets/credential_form.dart';
import '../../widgets/fab.dart';
import '../../widgets/info_box.dart';
import '../../widgets/own_progress_indicator.dart';
import '../../widgets/password_field.dart';

/// A widget for uploading Untis credentials to Firestore.
///
/// The credentials are loaded from the [CredentialProvider].
/// The user has to enter a secret key to encrypt the credentials before uploading them.
/// Only the encrypted credentials are uploaded, the secret key is not stored or transmitted.
class UploadCredentials extends StatefulWidget {
  const UploadCredentials({super.key});

  @override
  State<UploadCredentials> createState() => _UploadCredentialsState();
}

class _UploadCredentialsState extends State<UploadCredentials> {
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final credentials = context.read<CredentialProvider>().credentials;
    if (credentials != null) {
      setState(() {
        _usernameController.text = credentials.username;
        _passwordController.text = credentials.password;
        _schoolController.text = credentials.school;
        _serverController.text = credentials.server;
      });
    } else {
      context.pop();
    }
  }

  @override
  void dispose() {
    _secretController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _schoolController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prüfe, ob die Credentials bereits hochgeladen wurden
    final untisProvider = Provider.of<CredentialProvider>(context);
    final bool alreadyUploaded =
        untisProvider.credentialsOnlineStatus == CredentailsOnlineStatus.online;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmeldedaten online speichern'),
      ),
      // GestureDetector beibehalten, um die Tastatur auszublenden
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              OwnProgressIndicator(
                active: _isLoading,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              // Hauptinhalt mit ScrollView im Expanded
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Zeige Info an, wenn die Daten bereits hochgeladen wurden
                      if (alreadyUploaded)
                        const InfoBox(
                          title: 'Hinweis',
                          paragraphs: [
                            'Deine Anmeldedaten wurden bereits erfolgreich online gespeichert. Eine erneute Speicherung überschreibt die bestehenden Daten.'
                          ],
                          icon: Icons.check_circle_outline,
                          accentColor: Colors.green,
                        ),

                      if (alreadyUploaded) standardGap(),
                      const Text(
                        'Gib einen geheimen Schlüssel ein, um deine Anmeldedaten sicher online zu speichern.',
                        style: TextStyle(fontSize: 16),
                      ),
                      standardGap(),

                      // Geheimes Schlüssel Textfeld mit Sichtbarkeitsumschaltung
                      UserPasswordField(
                        controller: _secretController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Dein geheimer Schlüssel darf nicht leer sein';
                          }
                          return null;
                        },
                      ),

                      standardGap(),
                      const Text(
                        'Deine aktuellen Untis-Anmeldedaten:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),

                      standardGap(),
                      // Deaktivierte CredentialForm zur Anzeige der aktuellen Daten
                      CredentialForm(
                        usernameController: _usernameController,
                        passwordController: _passwordController,
                        schoolController: _schoolController,
                        serverController: _serverController,
                        disabled: true, // Deaktiviert, nur zur Anzeige
                      ),
                      standardGap(),
                      // Informationstext zur Verschlüsselung mit dem aktualisierten InfoBox-Widget
                      const InfoBox(
                        title: 'Deine Daten sind sicher!',
                        paragraphs: [
                          'Deine Anmeldedaten werden mit diesem Schlüssel lokal verschlüsselt und nur in dieser verschlüsselten Form online gespeichert. Der Schlüssel selbst wird niemals übertragen.',
                          'Du benötigst diesen identischen Schlüssel für jeden zukünftigen Zugriff auf diese Daten. Bitte merke ihn dir gut oder speichere ihn sicher an einem anderen Ort.'
                        ],
                        icon: Icons.info_outline,
                      ),
                      buildFABGap()
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ExtendedFAB(
          onClick: save,
          active: !_isLoading,
          icon: Icons.cloud_upload,
          label: 'Hochladen'),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void save() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final secret = _secretController.text;
    final credentialProvider = context.read<CredentialProvider>();

    await credentialProvider
        .uploadCredentialsOnline(secret)
        .onError((error, _) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Hochladen der Anmeldedaten'),
          ),
        );
      }
    });

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
