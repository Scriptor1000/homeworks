import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/models/credentials.dart';

void main() {
  group('Untis Credential Model Tests', () {
    final UntisCredentials credentials = UntisCredentials(
      username: 'test',
      school: 'spezie',
      password: 'asg!',
      server: 'untis.com',
    );
    test('should serialize in json and back', () {
      // test
      final json = credentials.toJsonString();
      final fromJson = UntisCredentials.fromJsonString(json);
      // verify
      expect(fromJson.username, equals(credentials.username));
      expect(fromJson.password, equals(credentials.password));
      expect(fromJson.server, equals(credentials.server));
      expect(fromJson.school, equals(credentials.school));
    });

    test('hash should be the same for same values', () async {
      // setup
      final credentials2 = UntisCredentials(
        username: credentials.username,
        school: credentials.school,
        password: credentials.password,
        server: credentials.server,
      );
      // test
      final hash1 = await credentials.calculateHash();
      final hash2 = await credentials2.calculateHash();
      // verify
      expect(hash2, equals(hash1));
    });
  });
}
