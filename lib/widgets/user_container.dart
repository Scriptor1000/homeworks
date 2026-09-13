import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../provider/authentication_provider.dart';
import '../provider/credential_provider.dart';
import '../utilities/enums.dart';
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
  bool isAppleLoading = false;

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
    final hasApple = user.providerData.any((e) => e.providerId == 'apple.com');

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
                  hasApple,
                  hasEmailPassword,
                ),
              ),

              standardGap(),

              Expanded(
                child: _buildAppleButton(
                  context,
                  hasApple,
                  hasGoogle,
                  hasEmailPassword,
                ),
              ),
            ],
          ),

          standardGap(),

          // Abmelden-Button
          Row(
            children: [
              Expanded(
                child: _buildEmailPasswordButton(context, hasEmailPassword),
              ),
              standardGap(),
              Expanded(child: _buildActionCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
              onPressed: () => _signOut(),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Konto löschen'),
              onPressed: () => _deleteAccount(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginMethodCard({
    required FaIconData icon,
    required bool hasMethod,
    required String methodName,
    required String status,
    required FilledButton button,
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
                  icon,
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
            button,
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(
    BuildContext context,
    bool hasGoogle,
    bool hasApple,
    bool hasEmailPassword,
  ) {
    final theme = Theme.of(context);
    return _buildLoginMethodCard(
      icon: FontAwesomeIcons.google,
      hasMethod: hasGoogle,
      methodName: 'Google',
      status: hasGoogle ? 'Verknüpft' : 'Nicht verbunden',
      button: FilledButton.icon(
        onPressed: () {
          if (isGoogleLoading) return;
          if (hasGoogle) {
            if (!hasEmailPassword && !hasApple) {
              showSnackBar(
                'Google-Konto kann nicht getrennt werden, da es die einzige Anmeldemethode ist',
              );
              return;
            }
            _unlinkGoogleAccount();
          } else {
            _linkGoogleAccount(hasApple);
          }
        },
        icon: isGoogleLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(hasGoogle ? Icons.link_off : Icons.link, size: 16),
        label: Text(hasGoogle ? 'Trennen' : 'Verknüpfen'),
        style: FilledButton.styleFrom(
          backgroundColor: hasGoogle
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          foregroundColor: hasGoogle
              ? theme.colorScheme.onError
              : theme.colorScheme.onPrimary,
        ),
      ),
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
      button: FilledButton.icon(
        onPressed: () {
          if (hasEmailPassword) {
            _changeEmailPassword();
          } else {
            _setupEmailPassword();
          }
        },
        icon: Icon(hasEmailPassword ? Icons.edit : Icons.add, size: 16),
        label: Text(hasEmailPassword ? 'Ändern' : 'Einrichten'),
      ),
    );
  }

  Widget _buildAppleButton(
    BuildContext context,
    bool hasApple,
    bool hasGoogle,
    bool hasEmailPassword,
  ) {
    final theme = Theme.of(context);
    return _buildLoginMethodCard(
      icon: FontAwesomeIcons.apple,
      hasMethod: hasApple,
      methodName: 'Apple',
      status: hasApple ? 'Verknüpft' : 'Nicht verbunden',
      button: FilledButton.icon(
        onPressed: () {
          if (isGoogleLoading) return;
          if (hasApple) {
            if (!hasEmailPassword && !hasGoogle) {
              showSnackBar(
                'Google-Konto kann nicht getrennt werden, da es die einzige Anmeldemethode ist',
              );
              return;
            }
            _unlinkAppleAccount();
          } else {
            _linkAppleAccount();
          }
        },
        icon: isAppleLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(hasApple ? Icons.link_off : Icons.link, size: 16),
        label: Text(hasApple ? 'Trennen' : 'Verknüpfen'),
        style: FilledButton.styleFrom(
          backgroundColor: hasApple
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          foregroundColor: hasApple
              ? theme.colorScheme.onError
              : theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Future<bool> confirmDialog({
    required String title,
    required String content,
    required String confirmButtonText,
    ButtonStyle confirmButtonStyle = const ButtonStyle(),
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  style: confirmButtonStyle,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmButtonText),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _linkGoogleAccount(bool hasApple) async {
    final bool confirm =
        hasApple ||
        await confirmDialog(
          title: 'Google Konto verknüpfen',
          content:
              'Dein Google-Konto wird mit diesem Konto verknüpft, wodurch du dich auch mit Google anmelden kannst.'
              'Beachte, das dabei deine Email-Adresse von Google diesem Konto zugeordnet wird.'
              'Wenn du bei Apple deine E-Mail-Adresse verbirgt hast, wird die von Apple bereitgestellte '
              'private Relay-Adresse dann deiner Google-Email-Adresse zugeordnet.',
          confirmButtonText: 'Verknüpfen',
        );

    if (!confirm || !mounted) return;
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

  Future<void> _linkAppleAccount() async {
    final bool confirm = await confirmDialog(
      title: 'Apple-Konto verknüpfen',
      content:
          'Dein Apple-Konto wird mit diesem Konto verknüpft.'
          'Wenn du bei Apple deine E-Mail-Adresse verbirgst, wird die von Apple bereitgestellte private '
          'Relay-Adresse ebenfalls diesem Konto (einschließlich deiner Email) zugeordnet.',
      confirmButtonText: 'Verknüpfen',
    );

    if (!confirm || !mounted) return;

    setState(() {
      isAppleLoading = true;
    });
    try {
      await context.read<AuthenticationProvider>().authenticateWithApple();
    } catch (e) {
      showSnackBar('Fehler bei der Verknüpfung: $e');
    } finally {
      setState(() {
        isAppleLoading = false;
      });
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    // Bestätigungsdialog anzeigen
    final bool confirm = await confirmDialog(
      title: 'Google-Konto trennen',
      content:
          'Sind Sie sicher, dass Sie die Verknüpfung zu ihrem Google-Konto von diesem Konto trennen möchten?',
      confirmButtonText: 'Trennen',
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );

    // Wenn der Nutzer abgebrochen hat oder der Dialog anderweitig geschlossen wurde
    if (!confirm || !mounted) return;

    setState(() {
      isGoogleLoading = true;
    });
    await context.read<AuthenticationProvider>().unlinkFromGoogle();

    setState(() {
      isGoogleLoading = false;
    });
  }

  Future<void> _unlinkAppleAccount() async {
    // Bestätigungsdialog anzeigen
    final bool confirm = await confirmDialog(
      title: 'Apple-Konto trennen',
      content:
          'Sind Sie sicher, dass Sie die Verknüpfung zu ihrem Apple-Konto von diesem Konto trennen möchten?',
      confirmButtonText: 'Trennen',
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );

    // Wenn der Nutzer abgebrochen hat oder der Dialog anderweitig geschlossen wurde
    if (!confirm || !mounted) return;

    setState(() {
      isAppleLoading = true;
    });

    try {
      await context.read<AuthenticationProvider>().unlinkFromApple();
    } catch (e) {
      showSnackBar('Fehler bei der Entkoppelung: $e');
    } finally {
      setState(() {
        isAppleLoading = false;
      });
    }
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
        await context.read<AuthenticationProvider>().sendResetEmail();
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

  Future<void> _deleteAccount() async {
    final authProvider = context.read<AuthenticationProvider>();
    final user = authProvider.user!;

    final hasGoogle = user.providerData.any(
      (e) => e.providerId == 'google.com',
    );
    final hasEmailPassword = user.providerData.any(
      (e) => e.providerId == 'password',
    );
    final hasApple = user.providerData.any((e) => e.providerId == 'apple.com');

    final method = await _selectAuthicationMethod(
      hasGoogle,
      hasApple,
      hasEmailPassword,
    );

    if (method == null) {
      showSnackBar('Konto-Löschung abgebrochen');
      return;
    }

    String? password;
    if (method == .emailAndPassword) {
      password = await _passwordDialog();
      if (password == null || password.isEmpty) {
        showSnackBar('Konto-Löschung abgebrochen');
        return;
      }
    }

    await authProvider.deleteAccount(method, password);
  }

  Future<String?> _passwordDialog() {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController passwordController =
            TextEditingController();
        return AlertDialog(
          title: const Text('Passwort eingeben'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Passwort'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
              child: const Text('Bestätigen'),
            ),
          ],
        );
      },
    );
  }

  Future<AuthenticationMethod?> _selectAuthicationMethod(
    bool hasGoogle,
    bool hasApple,
    bool hasEmailPassword,
  ) {
    return showModalBottomSheet<AuthenticationMethod?>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            standardGap(),
            Text(
              'Konto löschen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Um dein Konto zu löschen, musst du dich authentifizieren. Wähle eine Methode aus, um fortzufahren.',
            ),

            if (hasGoogle)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.google),
                title: const Text('Google'),
                onTap: () async =>
                    Navigator.of(context).pop(AuthenticationMethod.google),
              ),
            if (hasApple)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.apple),
                title: const Text('Apple'),
                onTap: () async =>
                    Navigator.of(context).pop(AuthenticationMethod.apple),
              ),
            if (hasEmailPassword)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.envelope),
                title: const Text('Passwort / Email'),
                onTap: () async => Navigator.of(
                  context,
                ).pop(AuthenticationMethod.emailAndPassword),
              ),
          ],
        ),
      ),
    );
  }
}
