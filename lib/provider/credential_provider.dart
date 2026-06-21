import 'package:cryptography/cryptography.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../database/credentials.dart';
import '../database/models/credentials.dart';
import '../database/models/factory.dart';
import '../utilities/enums.dart';

/// Provider for managing Untis credentials
///
/// This class handles the loading, saving, and online status of Untis credentials.
/// It uses [FlutterSecureStorage] for local storage and [FirestoreCredentials] for online storage.
class CredentialProvider extends ChangeNotifier {
  static const credentialsKey = 'UntisCredentials';

  final FlutterSecureStorage _storage;
  final FirestoreCredentials _firestoreCredentials;
  final ItemFactory _itemFactory;

  UntisCredentials? _credentials; // locally stored credentials
  UntisSession? _session; // current Untis session
  UntisSessionStatus _sessionStatus = UntisSessionStatus.noCredentials;
  bool _isLoadingCredentials = false;

  CredentialsOnlineStatus _credentialsOnlineStatus =
      CredentialsOnlineStatus.loading;

  CredentialProvider(
      {required FirestoreCredentials firestoreCredentials,
      required ItemFactory itemFactory,
      required FlutterSecureStorage storage})
      : _firestoreCredentials = firestoreCredentials,
        _itemFactory = itemFactory,
        _storage = storage;

  /// Wheter the credentials are currently being loaded or the loading process is finished.
  bool get isLoading => _isLoadingCredentials;

  /// Whether the credentials are available.
  bool get hasCredentials => _credentials != null;

  /// The current online status of the credentials.
  CredentialsOnlineStatus get credentialsOnlineStatus =>
      _credentialsOnlineStatus;

  UntisSession? get session => _session;

  UntisSessionStatus get sessionStatus => _sessionStatus;

  /// The current Untis credentials
  UntisCredentials? get credentials => _credentials;

  /// Initializes the provider by loading credentials from local storage.
  ///
  /// This method should be called at the start of the application to ensure credentials are loaded or
  /// to refresh the the credentials and their onlineStatus.
  Future<void> initialize() async {
    _isLoadingCredentials = true;
    notifyListeners();
    await _loadCredentialsLocal();
    _isLoadingCredentials = false;
    if (kDebugMode) {
      debugPrint(
        'Loaded credentials from secure storage: ${_credentials != null ? 'present' : 'absent'}',
      );
    }

    await _loadOnlineStatus();
  }

  /// Sets the current credentials, saves locally, and creates a session
  Future<void> setCredentials(UntisCredentials credentials) async {
    final res = await _itemFactory.createUntisSession(credentials);
    if (res.status == UntisSessionStatus.error) {
      return Future.error('Anmeldung fehlgeschlagen.');
    } else if (res.status == UntisSessionStatus.invalidCredentials) {
      return Future.error('Ungültige Anmeldedaten.');
    } else if (res.session == null) {
      return Future.error('Unbekannter Fehler bei der Anmeldung.');
    }
    _credentials = credentials;
    _session = res.session;
    _sessionStatus = res.status;
    await _saveCredentialsLocal();
    notifyListeners();
    _loadOnlineStatus();
  }

  /// Loads credentials from local secure storage
  Future<void> _loadCredentialsLocal() async {
    _sessionStatus = UntisSessionStatus.loading;
    notifyListeners();
    final storedCredentials = await _storage.read(key: credentialsKey);
    if (storedCredentials != null) {
      _credentials = _itemFactory.untisCredentialsFromJSON(storedCredentials);
      final res = await _itemFactory.createUntisSession(_credentials!);
      _session = res.session;
      _sessionStatus = res.status;
    } else {
      _sessionStatus = UntisSessionStatus.noCredentials;
      notifyListeners();
      await _createSession();
    }
  }

  /// Creates a Untis session using current credentials
  Future<void> _createSession() async {
    if (_credentials == null) return;
    _sessionStatus = UntisSessionStatus.loading;
    notifyListeners();
    try {
      final res = await _itemFactory.createUntisSession(_credentials!);
      _session = res.session;
      _sessionStatus = res.status;
    } catch (e) {
      _sessionStatus = UntisSessionStatus.error;
      print('Error creating session: $e');
    }
    notifyListeners();
  }

  /// Saves the current credentials to local secure storage
  Future<void> _saveCredentialsLocal() async {
    if (_credentials != null) {
      await _storage.write(
          key: credentialsKey, value: _credentials!.toJsonString());
    }
  }

  /// Deletes the credentials from [FlutterSecureStorage].
  Future<void> clearCredentialsLocal() async {
    _credentials = null;
    _session = null;
    _sessionStatus = UntisSessionStatus.noCredentials;
    await _storage.delete(key: credentialsKey);
    notifyListeners();
  }

  /// Loads the credentials from Firestore.
  ///
  /// It uses the [FirestoreCredentials] class to fetch the credentials and
  /// decrypt them using the provided [password].
  Future<void> loadCredentialsOnline(String password) async {
    late final UntisCredentials? storedCredentials;
    try {
      storedCredentials = await _firestoreCredentials.loadCredentials(password);
    } on SecretBoxAuthenticationError catch (_) {
      return Future.error('Falsches Passwort.');
    }
    if (storedCredentials == null) {
      return Future.error('Keine Anmeldedaten gefunden.');
    }

    _credentials = storedCredentials;
    await _createSession();
    if (_sessionStatus != UntisSessionStatus.sessionAccomplished ||
        _session == null) {
      final String errorMessage;
      if (_sessionStatus == UntisSessionStatus.invalidCredentials) {
        errorMessage = 'Ungültige Anmeldedaten.';
      } else if (_sessionStatus == UntisSessionStatus.error) {
        errorMessage = 'Anmeldung fehlgeschlagen.';
      } else {
        // noCredentials, loading, or sessionAccomplished-with-null-session:
        // none of these should be reachable here, since _credentials was
        // just set and await _createSession() always resolves to a final status.
        Sentry.logger.error(
          'Unexpected UntisSessionStatus $_sessionStatus after '
              '_createSession() in loadCredentialsOnline (session: $_session)',
        );
        errorMessage = 'Unbekannter Fehler bei der Anmeldung.';
      }
      _credentials = null;
      _session = null;
      notifyListeners();
      return Future.error(errorMessage);
    }
    await _saveCredentialsLocal();
    _loadOnlineStatus();

    }

  /// Uploads the current credentials to Firestore.
  ///
  /// It uses the [FirestoreCredentials] class to save the credentials
  /// after encrypting them with the provided [password].
  Future<void> uploadCredentialsOnline(String password) async {
    if (_credentials == null) return;
    await _firestoreCredentials.saveCredentials(_credentials!, password);
    _credentialsOnlineStatus = CredentialsOnlineStatus.online;

    notifyListeners();
  }

  /// Loads the online status of credentials by comparing local and online hashes
  Future<void> _loadOnlineStatus() async {
    _credentialsOnlineStatus = CredentialsOnlineStatus.loading;
    notifyListeners();
    try {
      final storedHash = await _firestoreCredentials.checkCredentialsOnline();

      if (storedHash == null) {
        _credentialsOnlineStatus = CredentialsOnlineStatus.offline;
      } else {
        if (_credentials == null) {
          _credentialsOnlineStatus = CredentialsOnlineStatus.online;
        } else {
          final localHash = await _credentials!.calculateHash();
          if (localHash == storedHash) {
            _credentialsOnlineStatus = CredentialsOnlineStatus.online;
          } else {
            _credentialsOnlineStatus = CredentialsOnlineStatus.changed;
          }
        }
      }
    } catch (error, stackTrace) {
      _credentialsOnlineStatus = CredentialsOnlineStatus.error;
      print('Error checking credentials online status: $error');
      Sentry.captureException(error, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }
}
