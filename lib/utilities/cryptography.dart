import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class CredentialCryptography {
  final _algorithm = AesGcm.with256bits();
  final _hashAlgorithm = Sha256();

  final String _uid;

  CredentialCryptography({required String uid}) : _uid = uid;

  /// Encrypts [data] for the database using the [userPassword]
  ///
  /// Returns a base64 encoded [String] of the encrypted data.
  Future<String> databaseEncryption(String userPassword, String data) async {
    final salt = await _hashAlgorithm.hash(utf8.encode(_uid));
    final secret = await _pbkdf2(userPassword, salt.bytes, 100000);
    final encrypted = await _encrypt(utf8.encode(data), secret);
    return base64Encode(encrypted);
  }

  /// Decrypts data using the [userPassword]
  ///
  /// Return the original data as a [String].
  /// Throws an exception if decryption fails or [userPassword] is incorrect.
  Future<String> databaseDecryption(
      String userPassword, String encrypted) async {
    final salt = await _hashAlgorithm.hash(utf8.encode(_uid));
    final secret = await _pbkdf2(userPassword, salt.bytes, 100000);
    final decrypted = await _decrypt(base64Decode(encrypted), secret);
    return utf8.decode(decrypted);
  }

  Future<List<int>> _decrypt(Uint8List data, SecretKey secretKey) async {
    final secretBox = SecretBox.fromConcatenation(data,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength);
    final codeUnits = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return codeUnits;
  }

  Future<Uint8List> _encrypt(Uint8List data, SecretKey secretKey) async {
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
    );
    return secretBox.concatenation();
  }

  /// Derives a key using PBKDF2 from the given [password] and [salt].
  Future<SecretKey> _pbkdf2(String password, List<int> salt, int iterations) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _algorithm.secretKeyLength * 8,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}
