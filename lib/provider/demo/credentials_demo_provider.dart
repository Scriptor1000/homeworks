import 'package:cryptography/cryptography.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import '../../database/credentials.dart';
import '../../database/models/credentials.dart';
import '../../utilities/enums.dart';
import '../credential_provider.dart';

class CredentialsDemoProvider extends ChangeNotifier
    implements CredentialProvider {
  CredentialsOnlineStatus _credentialsOnlineStatus =
      CredentialsOnlineStatus.loading;

  UntisCredentials _credentials = UntisCredentials(
    school: 'Demo School',
    username: 'demo_user',
    password: 'demo_password',
    server: 'demo_server',
  );

  final FirestoreCredentials _firestoreCredentials;

  CredentialsDemoProvider({required FirestoreCredentials firestoreCredentials})
    : _firestoreCredentials = firestoreCredentials;

  @override
  bool get hasCredentials => true;

  @override
  UntisSession? get session => null;

  @override
  UntisSessionStatus get sessionStatus => .sessionAccomplished;

  @override
  bool get isLoading => false;

  @override
  CredentialsOnlineStatus get credentialsOnlineStatus =>
      _credentialsOnlineStatus;

  @override
  Future<void> clearCredentialsLocal() async {}

  @override
  UntisCredentials? get credentials => _credentials;

  @override
  Future<void> initialize() async {
    _loadOnlineStatus();
  }

  @override
  Future<void> setCredentials(UntisCredentials credentials) async {
    _credentials = credentials;
    notifyListeners();
  }

  @override
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
    _loadOnlineStatus();
  }

  @override
  Future<void> uploadCredentialsOnline(String password) async {
    await _firestoreCredentials.saveCredentials(_credentials, password);
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
        if (credentials == null) {
          _credentialsOnlineStatus = CredentialsOnlineStatus.online;
        } else {
          final localHash = await credentials!.calculateHash();
          if (localHash == storedHash) {
            _credentialsOnlineStatus = CredentialsOnlineStatus.online;
          } else {
            _credentialsOnlineStatus = CredentialsOnlineStatus.changed;
          }
        }
      }
    } catch (error, stackTrace) {
      _credentialsOnlineStatus = CredentialsOnlineStatus.error;
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    } finally {
      notifyListeners();
    }
  }
}
