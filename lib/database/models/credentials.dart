import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// A class representing Untis credentials.
class UntisCredentials {
  final String username;
  final String school;
  final String password;
  final String server;

  UntisCredentials({
    required this.username,
    required this.school,
    required this.password,
    required this.server,
  });

  String toJsonString() {
    final jsonMap = {
      'username': username,
      'school': school,
      'password': password,
      'server': server,
    };
    return jsonEncode(jsonMap);
  }

  /// Calculates a hash of the credentials using SHA-256.
  Future<String> calculateHash() async {
    final hashAlgorithm = Sha256();
    final hashSink = hashAlgorithm.newHashSink();

    hashSink.add(utf8.encode(password));
    hashSink.add(utf8.encode(school));
    hashSink.add(utf8.encode(server));
    hashSink.add(utf8.encode(username));

    hashSink.close();
    return hashSink.hash().then((hash) => base64Encode(hash.bytes));
  }

  factory UntisCredentials.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return UntisCredentials(
      username: json['username'],
      school: json['school'],
      password: json['password'],
      server: json['server'],
    );
  }
}
