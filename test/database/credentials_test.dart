import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/models/factory.dart';
import 'package:mockito/annotations.dart';

import 'package:homeworks/database/user.dart';
import 'package:homeworks/database/credentials.dart';
import 'package:homeworks/database/models/credentials.dart';
import 'package:homeworks/utilities/cryptography.dart';
import 'package:mockito/mockito.dart';

import 'credentials_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<CredentialCryptography>(),
  MockSpec<FirestoreUser>(),
  MockSpec<ItemFactory>(),
  MockSpec<UntisCredentials>(),
])
void main() {
  group('Credentials Online Storage Tests', () {
    late CredentialCryptography mockCryptography;
    late FirestoreUser mockFirestoreUser;
    late FakeFirebaseFirestore mockFirestore;
    late ItemFactory mockItemFactory;
    late FirestoreCredentials firestoreCredentials;
    late UntisCredentials credentials;

    const String uid = 'test-uid';
    const String userPassword = 'super secret!';

    const String jsonCredentials = 'json_encoded_credentials';
    const String credentialHash = 'credential_hash';
    const String encryptedCredentials = 'encrypted_credentials';

    setUp(() async {
      mockFirestore = FakeFirebaseFirestore();
      mockCryptography = MockCredentialCryptography();
      mockFirestoreUser = MockFirestoreUser();
      mockItemFactory = MockItemFactory();
      credentials = MockUntisCredentials();
      firestoreCredentials = FirestoreCredentials(
        firestoreUser: mockFirestoreUser,
        cryptography: mockCryptography,
        itemFactory: mockItemFactory,
      );

      when(credentials.toJsonString()).thenReturn(jsonCredentials);
      when(credentials.calculateHash()).thenAnswer((_) async => credentialHash);
      when(
        mockItemFactory.untisCredentialsFromJSON(jsonCredentials),
      ).thenReturn(credentials);

      when(mockFirestoreUser.userDocument).thenReturn(
        mockFirestore.collection(FirestoreUser.userCollection).doc(uid),
      );

      when(
        mockCryptography.databaseEncryption(userPassword, jsonCredentials),
      ).thenAnswer((_) async => encryptedCredentials);
      when(
        mockCryptography.databaseDecryption(userPassword, encryptedCredentials),
      ).thenAnswer((_) async => jsonCredentials);
    });

    test('should upload the credentials encrypted', () async {
      // test
      await firestoreCredentials.saveCredentials(credentials, userPassword);
      // verify
      final userDoc = await mockFirestoreUser.userDocument.get();
      final data = userDoc.data()!;

      final credentialHash = await credentials.calculateHash();

      verify(
        mockCryptography.databaseEncryption(userPassword, jsonCredentials),
      ).called(1);
      expect(
        data[FirestoreCredentials.credentialsField],
        equals(encryptedCredentials),
      );
      expect(
        data[FirestoreCredentials.credentialsHashField],
        equals(credentialHash),
      );
    });

    test('should decrypt downloaded credentials', () async {
      // setup
      await mockFirestoreUser.userDocument.set({
        FirestoreCredentials.credentialsField: encryptedCredentials,
      });
      // test
      final loadedCredentials = await firestoreCredentials.loadCredentials(
        userPassword,
      );
      // verify
      verify(
        mockCryptography.databaseDecryption(userPassword, encryptedCredentials),
      ).called(1);

      expect(loadedCredentials, isNotNull);
    });

    test('should return null when no credentials are there', () {
      // test
      final loadedCredentials = firestoreCredentials.loadCredentials(
        userPassword,
      );
      // verify
      expect(loadedCredentials, completion(isNull));
    });

    test('should return the hash when online check', () async {
      // setup
      final credentialHash = await credentials.calculateHash();
      await mockFirestoreUser.userDocument.set({
        FirestoreCredentials.credentialsHashField: credentialHash,
      });
      // test
      final storedHash = await firestoreCredentials.checkCredentialsOnline();
      // verify
      expect(storedHash, equals(credentialHash));
    });

    test('should return null when no hash is found', () async {
      // test
      final storedHash = await firestoreCredentials.checkCredentialsOnline();
      // verify
      expect(storedHash, isNull);
    });
  });
}
