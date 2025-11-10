import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../web_authentication/web_authentication.dart' as web;
import '../provider/authentication_provider.dart';
import '../utilities/enums.dart';

/// A simple authentication screen that allows users to log in with email/password or Google.
class Authentication extends StatefulWidget {
  const Authentication({super.key});

  @override
  State<Authentication> createState() => _AuthenticationState();
}

class _AuthenticationState extends State<Authentication> {
  /// Controller for the email input field.
  final TextEditingController _emailController = TextEditingController();

  /// Controller for the password input field.
  final TextEditingController _passwordController = TextEditingController();

  /// Controls whether the password is obscured (hidden) or visible.
  bool _obscurePassword = true;

  /// Indicates whether a login operation is currently in progress.
  bool _isLoading = false;

  @override
  void dispose() {
    // Dispose controllers to free resources.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the login process with email and password.
  void _emailLogin() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthenticationProvider>();
    await authProvider.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Handles the Google login process.
  void _googleLogin() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthenticationProvider>();
    await authProvider.authenticateWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = context.watch<AuthenticationProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background for the login screen.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.8),
                  colorScheme.primary,
                  colorScheme.primaryContainer,
                ],
              ),
            ),
          ),

          // Main content wrapped in SafeArea to avoid notches and system UI.
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo/icon
                      Icon(
                        Icons.school_rounded,
                        size: 80,
                        color: colorScheme.onPrimary,
                      ),

                      const SizedBox(height: 24),

                      // App name/title
                      Text(
                        'Homeworks',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Login Card with email/password fields and buttons
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        constraints: const BoxConstraints(
                          maxWidth: 500,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Login title
                            Text(
                              'Anmeldung',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Email input field
                            buildEmailField(colorScheme),
                            const SizedBox(height: 16),

                            // Password input field
                            buildPasswordField(colorScheme),
                            const SizedBox(height: 24),

                            // Login button
                            buildLoginButton(colorScheme),
                            const SizedBox(height: 20),

                            // Divider with "ODER"
                            buildDivider(),
                            const SizedBox(height: 20),

                            // Google Sign-in button (or web button if needed)
                            buildGoogleSignInButton(authProvider.googleSignInState),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a horizontal divider with "ODER" in the middle.
  Row buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade400)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'ODER',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade400)),
      ],
    );
  }

  /// Builds the email input field.
  TextFormField buildEmailField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'E-Mail',
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) => value == null || value.isEmpty
          ? 'Bitte gib deine E-Mail-Adresse ein.'
          : null,
    );
  }

  /// Builds the password input field with visibility toggle.
  TextFormField buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Passwort',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _emailLogin(),
      validator: (value) => value == null || value.isEmpty
          ? 'Bitte gib dein Passwort ein.'
          : null,
    );
  }

  /// Builds the login button with loading indicator.
  ElevatedButton buildLoginButton(ColorScheme colorScheme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _emailLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: _isLoading
          ? const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : const Text(
        'Anmelden',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Builds the Google sign-in button based on the platform/state.
  Widget buildGoogleSignInButton(GoogleSignInState supported) {
    return switch (supported) {
    // Google sign-in available
      GoogleSignInState.supported => OutlinedButton.icon(
        onPressed: _isLoading ? null : _googleLogin,
        icon: const FaIcon(
          FontAwesomeIcons.google,
          size: 18,
        ),
        label: const Text(
          'Mit Google anmelden',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

    // Google sign-in not available
      GoogleSignInState.notSupported => OutlinedButton.icon(
        onPressed: null,
        icon: const FaIcon(
          FontAwesomeIcons.triangleExclamation,
          color: Colors.red,
          size: 18,
        ),
        label: const Text(
          'Google Anmeldung nicht verfügbar',
          style: TextStyle(color: Colors.red),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

    // Web button required for Google sign-in
      GoogleSignInState.needWebButton =>
          SizedBox(height: 40, child: web.renderButton()),

    // Error state
      GoogleSignInState.error => OutlinedButton.icon(
        onPressed: null,
        icon: const FaIcon(
          FontAwesomeIcons.triangleExclamation,
          color: Colors.red,
          size: 18,
        ),
        label: const Text(
          'Fehler',
          style: TextStyle(color: Colors.red),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

    // Loading state
      GoogleSignInState.loading => OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
        label: const Text('Mit Google anmelden'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    };
  }
}
