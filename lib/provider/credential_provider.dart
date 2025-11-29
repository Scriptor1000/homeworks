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

  UntisCredentials? _credentials;
  UntisSession? _session;
  UntisSessionState _sessionState = UntisSessionState.noCredentials;
  bool _isLoadingCredentials = false;

  CredentailsOnlineStatus _credentialsOnlineStatus =
      CredentailsOnlineStatus.loading;

  CredentialProvider({
    required FirestoreCredentials firestoreCredentials,
    required ItemFactory itemFactory,
    required FlutterSecureStorage storage,
  }) : _firestoreCredentials = firestoreCredentials,
       _itemFactory = itemFactory,
       _storage = storage;

  /// Wheter the credentials are currently being loaded or the loading process is finished.
  bool get isLoading => _isLoadingCredentials;

  /// Whether the credentials are available.
  bool get hasCredentials => _credentials != null;

  /// The current online status of the credentials.
  CredentailsOnlineStatus get credentialsOnlineStatus =>
      _credentialsOnlineStatus;

  UntisSession? get session => _session;

  UntisSessionState get sessionState => _sessionState;

  set credentialsOnlineStatus(CredentailsOnlineStatus status) {
    _credentialsOnlineStatus = status;
    notifyListeners();
  }

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
    print('Loaded credentials: $_credentials');

    await _loadOnlineStatus();
  }

  Future<void> setCredentials(UntisCredentials credentials) async {
    _credentials = credentials;
    await _createSession();
    if (_sessionState == UntisSessionState.error) {
      _credentials = null;
      return Future.error('Anmeldung fehlgeschlagen.');
    }
    await _saveCredentialsLocal();
    _loadOnlineStatus();
  }

  Future<void> _loadCredentialsLocal() async {
    final storedCredentials = await _storage.read(key: credentialsKey);
    if (storedCredentials != null) {
      _credentials = _itemFactory.untisCredentialsFromJSON(storedCredentials);
      notifyListeners();
      await _createSession();
    }
  }

  Future<void> _createSession() async {
    if (_credentials == null) return;
    _sessionState = UntisSessionState.loading;
    notifyListeners();
    try {
      _session = await _itemFactory.createUntisSession(_credentials!);
      _sessionState = UntisSessionState.accomplished;
    } catch (e) {
      _sessionState = UntisSessionState.error;
      print('Error creating session: $e');
    }
    notifyListeners();
  }

  Future<void> _saveCredentialsLocal() async {
    if (_credentials != null) {
      await _storage.write(
        key: credentialsKey,
        value: _credentials!.toJsonString(),
      );
    }
  }

  /// Deletes the credentials from [FlutterSecureStorage].
  Future<void> clearCredentialsLocal() async {
    _credentials = null;
    _session = null;
    _sessionState = UntisSessionState.noCredentials;
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
    if (_sessionState == UntisSessionState.error) {
      _credentials = null;
      return Future.error('Anmeldung fehlgeschlagen.');
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
    _credentialsOnlineStatus = CredentailsOnlineStatus.online;

    notifyListeners();
  }

  Future<void> _loadOnlineStatus() async {
    _credentialsOnlineStatus = CredentailsOnlineStatus.loading;
    notifyListeners();
    try {
      final storedHash = await _firestoreCredentials.checkCredentialsOnline();

      if (storedHash == null) {
        _credentialsOnlineStatus = CredentailsOnlineStatus.offline;
      } else {
        if (_credentials == null) {
          _credentialsOnlineStatus = CredentailsOnlineStatus.online;
        } else {
          final localHash = await _credentials!.calculateHash();
          if (localHash == storedHash) {
            _credentialsOnlineStatus = CredentailsOnlineStatus.online;
          } else {
            _credentialsOnlineStatus = CredentailsOnlineStatus.changed;
          }
        }
      }
    } catch (error, stackTrace) {
      _credentialsOnlineStatus = CredentailsOnlineStatus.error;
      print('Error checking credentials online status: $error');
      Sentry.captureException(error, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }
}
