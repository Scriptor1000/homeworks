import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../database/allowed_emails.dart';
import '../utilities/enums.dart';
import '../utilities/global_snackbar.dart';

/// Authentication provider that handles Firebase authentication
/// via Google Sign-In and email/password login.
///
/// Responsibilities:
/// - Initialize Google sign-in
/// - Authenticate users with Google
/// - Link Google accounts to existing Firebase users
/// - Sign out / unlink accounts
/// - Authorize / revoke emails stored in Firestore
///
/// Exposes:
/// - The currently signed-in Firebase [user]
/// - The current [googleSignInState] used for UI decisions
class AuthenticationProvider extends ChangeNotifier {
  /// FirebaseAuth instance used for authentication.
  final FirebaseAuth _firebaseAuth;

  /// Google Sign-In handler.
  final GoogleSignIn _googleSignIn;

  /// Helper to check and manage allowed emails stored in Firestore.
  final FirestoreAllowedEmails _allowedEmails;

  /// Completer resolved once Google sign-in support is determined.
  final Completer<bool> _googleSupported = Completer<bool>();

  /// State describing whether Google sign-in is supported, errors, etc.
  GoogleSignInState googleSignInState = GoogleSignInState.loading;

  /// Currently authenticated Firebase user.
  User? get user => _firebaseAuth.currentUser;

  /// OAuth Client ID used for Google authentication.
  static const clientId =
      '626284965826-iovj6s0lvft551f3d6ahdr6qkoc53njg.apps.googleusercontent.com';

  /// Creates a new [AuthenticationProvider].
  ///
  /// Required:
  /// - [firebaseAuth] Firebase authentication service
  /// - [googleSignIn] Google sign-in instance
  /// - [allowedEmails] Firestore helper for allowed email management
  AuthenticationProvider({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirestoreAllowedEmails allowedEmails,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _allowedEmails = allowedEmails;

  /// Initializes Google Sign-In compatibility and event listeners.
  ///
  /// - Sets [googleSignInState] according to support
  /// - Completes `_googleSupported` future
  /// - On web, listens to Google authentication events
  Future<void> initialize() async {
    if (_googleSupported.isCompleted) return;

    await _googleSignIn.initialize(clientId: clientId);

    try {
      if (_googleSignIn.supportsAuthenticate()) {
        googleSignInState = GoogleSignInState.supported;
        return _googleSupported.complete(true);
      } else if (kIsWeb) {
        // Web button authentication: events must be listened to manually
        _googleSignIn.authenticationEvents.listen((event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _handleGoogleCredentials(event.user);
          }
        });
        googleSignInState = GoogleSignInState.needWebButton;
      } else {
        googleSignInState = GoogleSignInState.notSupported;
      }
    } catch (error) {
      print('Google Sign-In initialization error: $error');
      googleSignInState = GoogleSignInState.error;
    }

    notifyListeners();
    _googleSupported.complete(false);
  }

  /// Begins Google sign-in flow.
  ///
  /// If supported, attempts to authenticate via Google credentials.
  /// Shows snackbars on error.
  Future<void> authenticateWithGoogle() async {
    if (!(await _googleSupported.future)) return;

    try {
      final googleUser = await _googleSignIn.authenticate();
      return await _handleGoogleCredentials(googleUser);
    } catch (error) {
      // TODO: switch error code if GoogleSignInException
      await _googleSignIn.disconnect();
      showSnackBar('Fehler bei der Anmeldung: $error');
    }
  }

  /// Decides whether to sign in or link credentials based on existing user state.
  Future<void> _handleGoogleCredentials(GoogleSignInAccount googleUser) async {
    if (_firebaseAuth.currentUser == null) {
      return _signInWithGoogle(googleUser);
    } else {
      return _linkWithGoogle(googleUser);
    }
  }

  /// Signs in a new user via Google OAuth.
  ///
  /// Steps:
  /// 1. Check email is allowed via Firestore
  /// 2. Create Firebase credential from Google ID token
  /// 3. Sign in to Firebase
  /// 4. Remove temporary invitation entries if required
  Future<void> _signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final allowed = await _allowedEmails.isEmailAllowed(googleUser.email);

      if (!allowed) {
        print('Email not allowed: ${googleUser.email}');
        showSnackBar(
          'Kein Zugang mit dieser Email (${googleUser.email}) möglich.'
              ' Bitte wende dich an den Administrator.',
        );
        await _googleSignIn.disconnect();
        return;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _allowedEmails.removeTemporaryEntries(
          googleUser.email,
          user.uid,
        );
      }

      notifyListeners();
    } catch (error) {
      print('Google Sign-In error: $error');

      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
      showSnackBar('Fehler bei der Anmeldung: $error');
      rethrow;
    }
  }

  /// Links Google credentials to an existing Firebase user.
  ///
  /// Also:
  /// - Updates profile picture & display name if needed
  /// - Calls Firestore to authorize email
  Future<void> _linkWithGoogle(GoogleSignInAccount googleUser) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      print('No user logged in; cannot link.');
      return;
    }

    try {
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await user.linkWithCredential(credential);

      // Optionally update user info after linking
      if (googleUser.photoUrl != null) {
        await user.updatePhotoURL(googleUser.photoUrl);
      }
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(googleUser.displayName);
      }
      await user.reload();

      await _allowedEmails.authorizeEmail(googleUser.email, user.uid);

      notifyListeners();
    } catch (error) {
      print('Google linking error: $error');
      showSnackBar('Fehler bei der Verknüpfung: $error');
    }
  }

  /// Unlinks Firebase user from Google provider.
  ///
  /// - Does NOT delete profile info
  /// - Revokes allowed email associated with the user
  Future<void> unlinkFromGoogle() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      print('No user logged in; cannot unlink.');
      return;
    }

    try {
      await user.unlink('google.com');
      await _googleSignIn.disconnect();
      await _allowedEmails.revokeEmail(user.uid);
    } catch (error) {
      print('Google unlink failed: $error');
      showSnackBar('Fehler bei der Trennung: $error');
    }
  }

  /// Signs the Firebase user out, and disconnects Google session.
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
    } catch (error) {
      print('Google sign-out failed: $error');
    }
  }

  /// Logs in using email + password via Firebase.
  ///
  /// Shows a snackbar on failure.
  Future<void> loginWithEmail(String email, String password) async {
    final credentials = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    try {
      await _firebaseAuth.signInWithCredential(credentials);
    } catch (e) {
      print('Error logging in with email: $e');
      showSnackBar(
        'Anmeldung fehlgeschlagen: '
            '${e is FirebaseAuthException ? _getErrorMessage(e) : e.toString()}',
      );
    }
  }

  /// Human-friendly Firebase Auth error strings.
  static String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Kein Benutzer mit dieser E-Mail gefunden';
      case 'invalid-credential':
        return 'Anmeldedaten ungültig';
      case 'invalid-email':
        return 'Ungültige E-Mail-Adresse';
      case 'user-disabled':
        return 'Dieser Benutzer wurde deaktiviert';
      default:
        return e.message ?? 'Ein unbekannter Fehler ist aufgetreten';
    }
  }
}
