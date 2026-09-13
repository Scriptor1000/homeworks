import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../provider/authentication_provider.dart';
import '../provider/credential_provider.dart';
import '../utilities/global_snackbar.dart';
import 'fab.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A widget that displays user information and allows account management.
///
/// Shows the user's profile picture, name, email, and linked accounts.
/// It provides options to link or unlink Google accounts and manage email/password credentials.
/// Also it shows a sign-out button which additionally deletes all local data.
class UserContainer extends StatefulWidget {
  const UserContainer({super.key});

  @override
  State<UserContainer> createState() => _UserContainerState();
}

class _UserContainerState extends State<UserContainer> {
  bool isGoogleLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthenticationProvider>();
    final user = authProvider.user!;

    final hasGoogle = user.providerData.any(
      (e) => e.providerId == 'google.com',
    );
    final hasEmailPassword = user.providerData.any(
      (e) => e.providerId == 'password',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          user.photoURL != null && user.photoURL!.isNotEmpty
              ? CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundImage: NetworkImage(user.photoURL!),
                  child: Icon(
                    Icons.person,
                    size: 40.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : CircleAvatar(
                  radius: 40,
                  child: Icon(
                    Icons.person,
                    size: 40.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
          const SizedBox(height: 16.0),

          // Benutzername
          Text(
            user.displayName ?? 'Benutzer',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          // E-Mail
          if (user.email != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                user.email!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

          standardGap(),

          // Anmelde-Buttons in einer Reihe
          Row(
            children: [
              // Google Sign-In Button
              Expanded(
                child: _buildGoogleSignInButton(
                  context,
                  hasGoogle,
                  hasEmailPassword,
                ),
              ),

              const SizedBox(width: 12),

              // Email/Passwort Button
              Expanded(
                child: _buildEmailPasswordButton(context, hasEmailPassword),
              ),
            ],
          ),

          standardGap(),

          // Abmelden-Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Abmelden'),
            onPressed: () => _signOut(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMethodCard({
    required FaIconData icon,
    required bool hasMethod,
    required String methodName,
    required String status,
    required String buttonLabel,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    ThemeData theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.google,
                  color: hasMethod ? Colors.green : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  methodName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasMethod)
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasMethod
                        ? Colors.green
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(hasMethod ? Icons.link_off : Icons.link, size: 16),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: hasMethod
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                foregroundColor: hasMethod
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(
    BuildContext context,
    bool hasGoogle,
    bool hasEmailPassword,
  ) {
    return _buildLoginMethodCard(
      icon: FontAwesomeIcons.google,
      hasMethod: hasGoogle,
      methodName: 'Google',
      status: hasGoogle ? 'Verknüpft' : 'Nicht verbunden',
      buttonLabel: hasGoogle ? 'Trennen' : 'Verknüpfen',
      onPressed: () {
        if (isGoogleLoading) return;
        if (hasGoogle) {
          if (!hasEmailPassword) {
            showSnackBar(
              'Google-Konto kann nicht getrennt werden, da es die einzige Anmeldemethode ist',
            );
            return;
          }
          _unlinkGoogleAccount();
        } else {
          _linkGoogleAccount();
        }
      },
      isLoading: isGoogleLoading,
    );
  }

  Widget _buildEmailPasswordButton(
    BuildContext context,
    bool hasEmailPassword,
  ) {
    return _buildLoginMethodCard(
      icon: FontAwesomeIcons.envelope,
      hasMethod: hasEmailPassword,
      methodName: 'Passwort',
      status: hasEmailPassword ? 'Eingerichtet' : 'Nicht eingerichtet',
      buttonLabel: hasEmailPassword ? 'Ändern' : 'Einrichten',
      onPressed: () {
        if (hasEmailPassword) {
          _changeEmailPassword();
        } else {
          _setupEmailPassword();
        }
      },
      isLoading: false,
    );
  }

  Future<void> _linkGoogleAccount() async {
    setState(() {
      isGoogleLoading = true;
    });
    try {
      await context.read<AuthenticationProvider>().authenticateWithGoogle();
    } catch (e) {
      showSnackBar('Fehler bei der Verknüpfung: $e');
    } finally {
      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    // Bestätigungsdialog anzeigen
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Google-Konto entfernen'),
          content: const Text(
            'Möchtest du wirklich dein Google-Konto von dieser App entfernen? Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Entfernen'),
            ),
          ],
        );
      },
    );

    // Wenn der Nutzer abgebrochen hat oder der Dialog anderweitig geschlossen wurde
    if (confirm != true || !mounted) return;

    setState(() {
      isGoogleLoading = true;
    });
    await context.read<AuthenticationProvider>().unlinkFromGoogle();

    setState(() {
      isGoogleLoading = false;
    });
  }

  Future<void> _setupEmailPassword() async {
    // TODO: Implementiere E-Mail/Passwort-Einrichtung
    // Diese Funktion sollte einen Dialog oder eine neue Seite öffnen,
    // in der der Benutzer ein Passwort für seine E-Mail-Adresse festlegen kann.
    // Verwende FirebaseAuth.linkWithCredential() mit EmailAuthProvider.credential()
    showSnackBar('E-Mail/Passwort-Einrichtung noch nicht implementiert');
  }

  Future<void> _changeEmailPassword() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Passwort zurücksetzen'),
        content: Text(
          'Wenn Sie ihr Passwort ändern wollen, wird Ihnen eine E-Mail zum Zurücksetzen ihres Passworts geschickt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendResetEmail();
            },
            child: Text('E-Mail senden'),
          ),
        ],
      ),
    );
    // TODO: Implementiere Passwort-Änderung
    // Diese Funktion sollte einen Dialog öffnen, in dem der Benutzer
    // sein aktuelles Passwort bestätigt und ein neues festlegt.
    // Verwende FirebaseAuth.updatePassword() nach Re-Authentifizierung
  }

  Future<void> _sendResetEmail() async {
    String message;

    final email = context.read<AuthenticationProvider>().user?.email;

    if (email == null || email.trim().isEmpty) {
      message =
          'Für dieses Konto ist keine E-Mail-Adresse hinterlegt. Bitte hinterlegen Sie zuerst eine E-Mail-Adresse.';
    } else {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        message =
            'E-Mail gesendet. Falls sie nicht eingetroffen ist, bitte Spam-Ordner und die eingegebene E-Mail überprüfen.';
      } on FirebaseAuthException {
        message = 'Fehler beim Senden der E-Mail';
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    await Future.wait([
      context.read<AuthenticationProvider>().signOut(),
      context.read<CredentialProvider>().clearCredentialsLocal(),
    ]);

    showSnackBar('Erfolgreich abgemeldet');
  }
}
