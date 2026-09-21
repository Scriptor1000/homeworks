import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../database/allowed_emails.dart';
import '../database/user.dart';
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

  /// Firebase Auth provider for Apple Sign-In.
  final AppleAuthProvider _appleProvider;

  /// Completer resolved once Google sign-in support is determined.
  final Completer<bool> _googleSupported = Completer<bool>();

  /// State describing whether Google sign-in is supported, errors, etc.
  GoogleSignInState googleSignInState = GoogleSignInState.loading;

  /// Currently authenticated Firebase user.
  User? get user => _firebaseAuth.currentUser;

  /// Client ID for the Google Sign-In.
  static const webClientId =
      '626284965826-iovj6s0lvft551f3d6ahdr6qkoc53njg.apps.googleusercontent.com';

  /// Creates a new [AuthenticationProvider].
  ///
  /// Required:
  /// - [_firebaseAuth] Firebase authentication service
  /// - [_googleSignIn] Google sign-in instance
  /// - [allowedEmails] Firestore helper for allowed email management
  AuthenticationProvider({
    required this._firebaseAuth,
    required this._googleSignIn,
    required this._appleProvider,
    required FirestoreAllowedEmails allowedEmails,
  });

  /// Initializes Google Sign-In compatibility and event listeners.
  ///
  /// - Sets [googleSignInState] according to support
  /// - Completes `_googleSupported` future
  /// - On web, listens to Google authentication events
  Future<void> initialize() async {
    if (_googleSupported.isCompleted) return;
    try {
      await _googleSignIn.initialize(clientId: kIsWeb ? webClientId : null);

      if (_googleSignIn.supportsAuthenticate()) {
        googleSignInState = GoogleSignInState.supported;
        notifyListeners();
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
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
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
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());

      showSnackBar('Eine E-Mail zum Zurücksetzen wurde gesendet.');
    } on FirebaseAuthException catch (e) {
      showSnackBar(_getErrorMessage(e));
    } catch (e) {
      showSnackBar('$e');
    }
  }

  /// Registers a new user with email & password.
  ///
  /// Does NOT automatically log in — Firebase does this implicitly.
  /// Returns `null` if successful, or an error message on failure.
  Future<String?> registerWithEmail(String email, String password) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return '$e';
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

  /// Begins Apple sign-in flow.
  ///
  /// If the user is already signed in, links the Apple credentials to their account.
  /// If not, signs in with Apple credentials.
  Future<void> authenticateWithApple() async {
    try {
      if (user != null) {
        await user!.linkWithProvider(_appleProvider);
        return;
      }
      await _firebaseAuth.signInWithProvider(_appleProvider);
    } catch (error) {
      showSnackBar('Fehler bei der Anmeldung: $error');
    }
  }

  /// Unlinks the currently signed-in Firebase user from their Apple account.
  Future<void> unlinkFromApple() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    await user.unlink(_appleProvider.providerId);
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
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      notifyListeners();
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      // TODO Future.error

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

      notifyListeners();
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
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
      return;
    }
    await user.unlink(GoogleAuthProvider.PROVIDER_ID);
    await _googleSignIn.disconnect();
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
    final credentials = EmailAuthProvider.credential(
      email: trimmedEmail,
      password: password,
    );

    try {
      await _firebaseAuth.signInWithCredential(credentials);
    } catch (e) {
      showSnackBar(
        'Anmeldung fehlgeschlagen: ${e is FirebaseAuthException ? _getErrorMessage(e) : e.toString()}',
      );
    }
  }

  /// Sends a password reset email to the currently signed-in user.
  Future<void> sendResetEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      return;
    }
    await _firebaseAuth.sendPasswordResetEmail(email: user.email!);
  }

  /// Deletes the currently signed-in user's account from Firebase Auth WARNING! Use with caution.
  Future<void> deleteAccount(
    AuthenticationMethod reauthenticationMethod,
    FirestoreUser firestoreUser,
    String? password,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    if (user.providerData.any(
      (provider) => provider.providerId == AppleAuthProvider.PROVIDER_ID,
    )) {
      reauthenticationMethod = AuthenticationMethod.apple;
    }

    switch (reauthenticationMethod) {
      case .apple:
        final credentials = await user.reauthenticateWithProvider(
          _appleProvider,
        );
        if (credentials.additionalUserInfo?.authorizationCode == null) break;
        await _firebaseAuth.revokeTokenWithAuthorizationCode(
          credentials.additionalUserInfo!.authorizationCode!,
        );
        break;
      case .google:
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        break;
      case .emailAndPassword:
        if (user.email == null || password == null) {
          throw Exception('Email or password is null');
        }
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        break;
    }

    await firestoreUser.deleteAllData();
    await user.delete();
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
