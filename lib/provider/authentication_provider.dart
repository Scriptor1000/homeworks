import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../database/allowed_emails.dart';
import '../utilities/enums.dart';
import '../utilities/global_snackbar.dart';

class AuthenticationProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirestoreAllowedEmails _allowedEmails;

  final Completer<bool> _googleSupported = Completer<bool>();
  GoogleSignInState googleSignInState = GoogleSignInState.loading;

  User? get user => _firebaseAuth.currentUser;

  /// Client ID for the Google Sign-In.
  static const clientId =
      '626284965826-iovj6s0lvft551f3d6ahdr6qkoc53njg.apps.googleusercontent.com';

  AuthenticationProvider({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirestoreAllowedEmails allowedEmails,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _allowedEmails = allowedEmails;

  Future<void> initialize() async {
    if (_googleSupported.isCompleted) return;
    await _googleSignIn.initialize(
      clientId: clientId,
    );
    try {
      if (_googleSignIn.supportsAuthenticate()) {
        googleSignInState = GoogleSignInState.supported;
        return _googleSupported.complete(true);
      } else if (kIsWeb) {
        // on web, there is an extra button by Google to sign in
        // but this button doen't give us a callback so we have to listen to  events
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
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
      );
      googleSignInState = GoogleSignInState.error;
    }
    notifyListeners();
    _googleSupported.complete(false);
  }

  /// Starts the Google Sign-In process for linking and signing in.
  ///
  /// Lets the user sign in with their Google account and
  /// checks if the email is allowed. If the email is allowed,
  /// it signs in with Firebase.
  Future<void> authenticateWithGoogle() async {
    if (!(await _googleSupported.future)) {
      return;
    }
    try {
      final googleUser = await _googleSignIn.authenticate();
      return await _handleGoogleCredentials(googleUser);
    } catch (error) {
      // TODO swich the error code if it is a GoogleSignInException
      await _googleSignIn.disconnect();
      showSnackBar('Fehler bei der Anmeldung: $error');
    }
  }

  Future<void> _handleGoogleCredentials(GoogleSignInAccount googleUser) async {
    if (_firebaseAuth.currentUser == null) {
      return _signInWithGoogle(googleUser);
    } else {
      return _linkWithGoogle(googleUser);
    }
  }

  Future<void> _signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final allowed = await _allowedEmails.isEmailAllowed(googleUser.email);

      if (!allowed) {
        print('Email nicht erlaubt: ${googleUser.email}');
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
        await _allowedEmails.removeTemporaryEntries(googleUser.email, user.uid);
      }
      notifyListeners();
    } catch (error, stackTrace) {
      print('Google Sign-In Fehler: $error');
      // TODO Future.error
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
      );

      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
      showSnackBar('Fehler bei der Anmeldung: $error');
      rethrow;
    }
  }

  Future<void> _linkWithGoogle(GoogleSignInAccount googleUser) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      print('Kein Nutzer angemeldet, kann nicht verknüpfen.');
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
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
      );
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
      print('Kein Nutzer angemeldet, kann nicht trennen.');
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
