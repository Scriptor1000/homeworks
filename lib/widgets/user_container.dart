import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../provider/authentication_provider.dart';
import '../provider/credential_provider.dart';
import '../utilities/enums.dart';
import '../utilities/global_snackbar.dart';
import '../web_authentication/web_authentication.dart' as web;
import 'fab.dart';

/// A widget that displays user information and allows account management.
///
/// Shows the user's profile picture, name, email, and linked accounts.
/// It provides options to link or unlink Google accounts and manage email/password credentials.
/// Also it shows a sign-out button wich additionally deletes all local data.
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

  Widget _buildGoogleSignInButton(
    BuildContext context,
    bool hasGoogle,
    bool hasEmailPassword,
  ) {
    final authProvider = context.read<AuthenticationProvider>();

    // Für Web verwenden wir den renderButton wenn möglich
    if (kIsWeb &&
        authProvider.googleSignInState == GoogleSignInState.needWebButton) {
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
                  Icon(
                    FontAwesomeIcons.google,
                    color: hasGoogle
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Google',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasGoogle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Verknüpft',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.green),
                    ),
                  ],
                )
              else
                Text(
                  'Nicht verbunden',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              const SizedBox(height: 12),
              if (hasGoogle && hasEmailPassword)
                FilledButton.icon(
                  onPressed: isGoogleLoading ? null : _unlinkGoogleAccount,
                  icon: isGoogleLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_off, size: 16),
                  label: const Text('Trennen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                )
              else if (hasGoogle)
                FilledButton.icon(
                  onPressed: () => showSnackBar(
                    'Google-Konto kann nicht getrennt werden, da es die einzige Anmeldemethode ist',
                  ),
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('Trennen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.12),
                    foregroundColor: Theme.of(context).colorScheme.outline,
                  ),
                )
              else
                web.renderButton(),
            ],
          ),
        ),
      );
    }

    // Für andere Plattformen normaler Button
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
                Icon(
                  FontAwesomeIcons.google,
                  color: hasGoogle
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Google',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasGoogle)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Verknüpft',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.green),
                  ),
                ],
              )
            else
              Text(
                'Nicht verbunden',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            const SizedBox(height: 12),
            if (hasGoogle && hasEmailPassword)
              FilledButton.icon(
                onPressed: isGoogleLoading ? null : _unlinkGoogleAccount,
                icon: isGoogleLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_off, size: 16),
                label: const Text('Trennen'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
              )
            else if (hasGoogle)
              FilledButton.icon(
                onPressed: () => showSnackBar(
                  'Google-Konto kann nicht getrennt werden, da es die einzige Anmeldemethode ist',
                ),
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Trennen'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacity(0.12),
                  foregroundColor: Theme.of(context).colorScheme.outline,
                ),
              )
            else
              FilledButton.icon(
                onPressed: isGoogleLoading ? null : _linkGoogleAccount,
                icon: isGoogleLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link, size: 16),
                label: const Text('Verknüpfen'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailPasswordButton(
    BuildContext context,
    bool hasEmailPassword,
  ) {
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
                Icon(
                  Icons.lock,
                  color: hasEmailPassword
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Passwort',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasEmailPassword)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Eingerichtet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.green),
                  ),
                ],
              )
            else
              Text(
                'Nicht eingerichtet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            const SizedBox(height: 12),
            if (hasEmailPassword)
              FilledButton.icon(
                onPressed: _changeEmailPassword,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Ändern'),
              )
            else
              FilledButton.icon(
                onPressed: _setupEmailPassword,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Einrichten'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _linkGoogleAccount() async {
    setState(() {
      isGoogleLoading = true;
    });
    try {
      await context.read<AuthenticationProvider>().authenticateWithGoogle();
    } catch (e) {
      print('Fehler beim Verknüpfen mit Google: $e');
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
    print('TODO: E-Mail/Passwort-Einrichtung implementieren');
  }

  Future<void> _changeEmailPassword() async {
    // TODO: Implementiere Passwort-Änderung
    // Diese Funktion sollte einen Dialog öffnen, in dem der Benutzer
    // sein aktuelles Passwort bestätigt und ein neues festlegt.
    // Verwende FirebaseAuth.updatePassword() nach Re-Authentifizierung
    showSnackBar('Passwort-Änderung noch nicht implementiert');
    print('TODO: Passwort-Änderung implementieren');
  }

  Future<void> _signOut() async {
    await context.read<CredentialProvider>().clearCredentialsLocal();
    await context.read<AuthenticationProvider>().signOut();

    showSnackBar('Erfolgreich abgemeldet');
  }
}
