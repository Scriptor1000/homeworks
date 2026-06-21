import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  /// Client ID for the Google Sign-In.
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
          // the event could also be a sign out event
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _handleGoogleCredentials(event.user);
          }
        });
        googleSignInState = GoogleSignInState.needWebButton;
      } else {
        googleSignInState = GoogleSignInState.notSupported;
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Google Sign-In Initialisierungsfehler: $error');
      }
      Sentry.captureException(error, stackTrace: stackTrace);
      googleSignInState = GoogleSignInState.error;
    }

    notifyListeners();
    _googleSupported.complete(false);
  }

  /// Sends a password reset email.
  ///
  /// Shows a snackbar with success or error messages.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(),
      );

      showSnackBar("Eine E-Mail zum Zurücksetzen wurde gesendet.");
    } on FirebaseAuthException catch (e) {
      showSnackBar(
        "${_getErrorMessage(e)}",
      );
    } catch (e) {
      showSnackBar("$e");
    }
  }

  /// Registers a new user with email & password.
  ///
  /// Does NOT automatically log in — Firebase does this implicitly.
  /// Returns `null` if successful, or an error message on failure.
  Future<String?> registerWithEmail(
      String email,
      String password,
      ) async {
    final trimmedEmail = email.trim();
    final allowed = await _allowedEmails.isEmailAllowed(trimmedEmail);
    if (!allowed) {
      return 'Kein Zugang mit dieser Email möglich. Bitte wende dich an den Administrator.';
    }
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return "$e";
    }
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
      // TODO swich the error code if it is a GoogleSignInException
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
            ' Bitte wende dich an den Administrator.');
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
    } catch (error, stackTrace) {
      print('Google Sign-In Fehler: $error');
      // TODO Future.error
      Sentry.captureException(error, stackTrace: stackTrace);

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

      if (googleUser.photoUrl != null) {
        await user.updatePhotoURL(googleUser.photoUrl);
      }
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(googleUser.displayName);
      }
      await user.reload();

      await _allowedEmails.authorizeEmail(googleUser.email, user.uid);

      notifyListeners();
    } catch (error, stackTrace) {
      Sentry.captureException(error, stackTrace: stackTrace);
      print('Google Verknüpfungsfehler: $error');
      showSnackBar('Fehler bei der Verknüpfung: $error');
    }
  }

  /// Unlinks the currently signed-in Firebase user from their Google account.
  ///
  /// This method will unlink the Firebase user from their Google account.
  /// It will not delete the display name or photo URL, but will remove the
  /// Google account association. The email will be revoked from the allowed emails.
  Future<void> unlinkFromGoogle() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      print('No user logged in; cannot unlink.');
      return;
    }

    await user.unlink('google.com');
    await _googleSignIn.disconnect();
    await _allowedEmails.revokeEmail(user.uid);
  }

  /// Signs out the currently signed-in user from their Google account.
  ///
  /// In future sign ins, the user will have to select their Google account again.
  /// This method does not unlink the Firebase user from their Google account.
  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    await _firebaseAuth.signOut();
  }

  /// Logs in using email + password via Firebase.
  ///
  /// Shows a snackbar on failure.
  Future<void> loginWithEmail(String email, String password) async {
    final trimmedEmail = email.trim();
    final allowed = await _allowedEmails.isEmailAllowed(trimmedEmail);
    if (!allowed) {
      showSnackBar(
          'Kein Zugang mit dieser Email möglich. Bitte wende dich an den Administrator.');
      return;
    }
    final credentials = EmailAuthProvider.credential(
      email: trimmedEmail,
      password: password,
    );

    try {
      await _firebaseAuth.signInWithCredential(credentials);
    } catch (e) {
      print('Error logging in with email: $e');
      showSnackBar(
          'Anmeldung fehlgeschlagen: ${e is FirebaseAuthException ? _getErrorMessage(e) : e.toString()}');
    }
  }

  /// The error messages for FirebaseAuth exceptions.
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
