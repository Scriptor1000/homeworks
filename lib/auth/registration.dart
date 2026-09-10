import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/authentication_provider.dart';

/// A simple registration screen that allows users to log in with email/password or Google.
class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  /// Controller for the email input field.
  final TextEditingController _emailController = TextEditingController();

  /// Controller for the password input field.
  final TextEditingController _passwordController = TextEditingController();

  /// Controller for the second password input field.
  final TextEditingController _passwordController2 = TextEditingController();

  /// Controls whether the password is obscured (hidden) or visible.
  bool _obscurePassword = true;

  /// Indicates whether a login operation is currently in progress.
  bool _isLoading = false;

  @override
  void dispose() {
    // Dispose controllers to free resources.
    _emailController.dispose();
    _passwordController.dispose();
    _passwordController2.dispose();
    super.dispose();
  }

  /// Handles the login process with email and password.

  Future<void> _register() async {
    if (_passwordController.text != _passwordController2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Die Passwörter stimmen nicht überein.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthenticationProvider>();
    final error = await authProvider.registerWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Registrierung erfolgreich!')),
    );
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    //final authProvider = context.watch<AuthenticationProvider>();

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
                        constraints: const BoxConstraints(maxWidth: 500),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
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
                              'Registrierung',
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
                            buildPasswordField(
                              colorScheme,
                              _passwordController,
                              'Passwort',
                            ),
                            const SizedBox(height: 24),

                            // second Password input field
                            buildPasswordField(
                              colorScheme,
                              _passwordController2,
                              'Passwort bestätigen',
                            ),
                            const SizedBox(height: 24),

                            // Register button
                            buildRegisterButton(colorScheme),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Zurück',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
  TextFormField buildPasswordField(
    ColorScheme colorScheme,
    TextEditingController controller,
    String txt,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: txt,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      validator: (value) => value == null || value.isEmpty
          ? 'Bitte gib dein Passwort ein.'
          : null,
    );
  }

  ElevatedButton buildRegisterButton(ColorScheme colorScheme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _register,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'Registrieren',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
