import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/credentials.dart';
import '../utilities/cryptography.dart';
import 'models/factory.dart';
import 'user.dart';

/// Klasse für das Handling von Credentials in Firestore.
class FirestoreCredentials {
  static const credentialsField = 'UntisCredentials';
  static const credentialsHashField = 'UntisCredentialsHash';

  final FirestoreUser _firestoreUser;
  final CredentialCryptography _cryptography;
  final ItemFactory _itemFactory;

  FirestoreCredentials({
    required FirestoreUser firestoreUser,
    required CredentialCryptography cryptography,
    required ItemFactory itemFactory,
  }) : _firestoreUser = firestoreUser,
       _cryptography = cryptography,
       _itemFactory = itemFactory;

  /// Saves the Untis credentials to Firestore.
  ///
  /// Uploads the [credentials] after encrypting them with [userPassword].
  /// It also saves a hash of the [credentials] for verification.
  Future<void> saveCredentials(
    UntisCredentials credentials,
    String userPassword,
  ) async {
    final encryptedCredentials = await _cryptography.databaseEncryption(
      userPassword,
      credentials.toJsonString(),
    );
    final credentialsHash = await credentials.calculateHash();

    await _firestoreUser.userDocument.set({
      credentialsField: encryptedCredentials,
      credentialsHashField: credentialsHash,
    }, SetOptions(merge: true));
  }

  /// Loads the Untis credentials from Firestore.
  ///
  /// Decrypts the in Firestore stored credentials using the provided [userPassword] and
  /// returns them.
  Future<UntisCredentials?> loadCredentials(String userPassword) async {
    final userDoc = await _firestoreUser.userDocument.get();

    if (!userDoc.exists) {
      return null;
    }

    final encryptedCredentials = userDoc[credentialsField];
    if (encryptedCredentials == null) {
      return null;
    }
    final credentialsJsonString = await _cryptography.databaseDecryption(
      userPassword,
      encryptedCredentials,
    );

    return _itemFactory.untisCredentialsFromJSON(credentialsJsonString);
  }

  /// The hash of the stored Untis credentials
  Future<String?> checkCredentialsOnline() async {
    final userDoc = await _firestoreUser.userDocument.get();

    try {
      final storedHash = userDoc[credentialsHashField];
      return storedHash;
    } on StateError {
      // SateError: Not found
      return null;
    }
  }
}
