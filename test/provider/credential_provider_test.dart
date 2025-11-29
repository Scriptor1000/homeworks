import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/credentials.dart';
import 'package:homeworks/database/models/credentials.dart';
import 'package:homeworks/database/models/factory.dart';
import 'package:homeworks/provider/credential_provider.dart';
import 'package:homeworks/utilities/enums.dart' hide test;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'credential_provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ItemFactory>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<UntisSession>(),
  MockSpec<FirestoreCredentials>(),
])
void main() {
  group('Credential Provider: ', () {
    late MockItemFactory itemFactory;
    late MockFlutterSecureStorage storage;
    late MockFirestoreCredentials firestoreCredentials;
    late MockUntisSession session;
    late CredentialProvider credentialProvider;

    const userPassword = 'password';
    const falsePassword = 'wrongPassword';
    const nonExistingPassword = 'nonExistingPassword';
    final testCredentials = UntisCredentials(
      school: 'school',
      username: 'username',
      password: 'password',
      server: 'server',
    );

    setUp(() {
      itemFactory = MockItemFactory();
      storage = MockFlutterSecureStorage();
      firestoreCredentials = MockFirestoreCredentials();
      session = MockUntisSession();
      credentialProvider = CredentialProvider(
        firestoreCredentials: firestoreCredentials,
        itemFactory: itemFactory,
        storage: storage,
      );

      when(
        firestoreCredentials.loadCredentials(userPassword),
      ).thenAnswer((_) async => testCredentials);
      when(
        firestoreCredentials.loadCredentials(falsePassword),
      ).thenThrow(Exception('Decryption failed'));

      when(
        storage.read(key: CredentialProvider.credentialsKey),
      ).thenAnswer((_) async => testCredentials.toJsonString());
      when(
        itemFactory.untisCredentialsFromJSON(testCredentials.toJsonString()),
      ).thenReturn(testCredentials);
      when(
        itemFactory.createUntisSession(testCredentials),
      ).thenAnswer((_) async => session);
    });

    test('should initializing by loading local and checking online', () async {
      // test
      await credentialProvider.initialize();
      // verify
      expect(credentialProvider.isLoading, isFalse);
      expect(credentialProvider.hasCredentials, isTrue);
      expect(credentialProvider.credentials, equals(testCredentials));
      expect(credentialProvider.session, equals(session));
      expect(
        credentialProvider.sessionState,
        equals(UntisSessionState.accomplished),
      );
      expect(
        credentialProvider.credentialsOnlineStatus,
        equals(CredentailsOnlineStatus.offline),
      );

      verify(storage.read(key: CredentialProvider.credentialsKey)).called(1);
      verify(
        itemFactory.untisCredentialsFromJSON(testCredentials.toJsonString()),
      ).called(1);
      verify(itemFactory.createUntisSession(testCredentials)).called(1);
      verify(firestoreCredentials.checkCredentialsOnline()).called(1);
      verifyNoMoreInteractions(storage);
      verifyNoMoreInteractions(itemFactory);
      verifyNoMoreInteractions(firestoreCredentials);
    });

    test(
      'should save credentials locally and reload online status on new credentials',
      () async {
        // test
        await credentialProvider.setCredentials(testCredentials);
        // verify
        expect(credentialProvider.hasCredentials, isTrue);
        expect(credentialProvider.credentials, equals(testCredentials));
        verify(itemFactory.createUntisSession(testCredentials)).called(1);
        verify(firestoreCredentials.checkCredentialsOnline()).called(1);
        verify(
          storage.write(
            key: CredentialProvider.credentialsKey,
            value: testCredentials.toJsonString(),
          ),
        ).called(1);
      },
    );

    test('should delete session and storage on clearing credentials', () async {
      // setup
      await credentialProvider.setCredentials(testCredentials);
      // test
      await credentialProvider.clearCredentialsLocal();
      // verify
      expect(credentialProvider.hasCredentials, isFalse);
      expect(credentialProvider.credentials, isNull);
      expect(credentialProvider.session, isNull);
      expect(
        credentialProvider.sessionState,
        equals(UntisSessionState.noCredentials),
      );
      verify(storage.delete(key: CredentialProvider.credentialsKey)).called(1);
    });

    test(
      'should save credentials local and create session on online load',
      () async {
        // test
        await credentialProvider.loadCredentialsOnline(userPassword);
        // verify
        expect(credentialProvider.hasCredentials, isTrue);
        expect(credentialProvider.credentials, equals(testCredentials));
        verify(firestoreCredentials.loadCredentials(userPassword)).called(1);
        verify(itemFactory.createUntisSession(testCredentials)).called(1);
        verify(
          storage.write(
            key: CredentialProvider.credentialsKey,
            value: testCredentials.toJsonString(),
          ),
        ).called(1);
      },
    );

    test('should handle error on wrong password for online load', () async {
      // test
      await credentialProvider.loadCredentialsOnline(falsePassword).catchError((
        e,
      ) {
        expect(e.toString(), contains('Exception: Decryption failed'));
      });
      // verify
      expect(credentialProvider.hasCredentials, isFalse);
      expect(credentialProvider.credentials, isNull);
      verify(firestoreCredentials.loadCredentials(falsePassword)).called(1);
      verifyNever(itemFactory.createUntisSession(any));
      verifyNever(
        storage.write(
          key: CredentialProvider.credentialsKey,
          value: anyNamed('value'),
        ),
      );
    });

    test(
      'should raise error if no credentials are found on online load ',
      () async {
        // test
        await credentialProvider
            .loadCredentialsOnline(nonExistingPassword)
            .catchError((e) {
              expect(e.toString(), contains('Keine Anmeldedaten gefunden'));
            });
        // verify
        expect(credentialProvider.hasCredentials, isFalse);
        expect(credentialProvider.credentials, isNull);
        verify(
          firestoreCredentials.loadCredentials(nonExistingPassword),
        ).called(1);
        verifyNever(itemFactory.createUntisSession(any));
        verifyNever(
          storage.write(
            key: CredentialProvider.credentialsKey,
            value: anyNamed('value'),
          ),
        );
      },
    );

    test(
      'should save credentials and change online status on upload',
      () async {
        // setup
        await credentialProvider.setCredentials(testCredentials);
        // test
        await credentialProvider.uploadCredentialsOnline(userPassword);
        // verify
        expect(
          credentialProvider.credentialsOnlineStatus,
          equals(CredentailsOnlineStatus.online),
        );
        verify(
          firestoreCredentials.saveCredentials(testCredentials, userPassword),
        ).called(1);
      },
    );

    test(
      'should not raise error if asked to upload non existend credentials',
      () async {
        // test
        await credentialProvider.uploadCredentialsOnline(userPassword);
        // verify
        expect(
          credentialProvider.credentialsOnlineStatus,
          isNot(equals(CredentailsOnlineStatus.online)),
        );
        verifyNever(firestoreCredentials.saveCredentials(any, any));
      },
    );
  });
}
