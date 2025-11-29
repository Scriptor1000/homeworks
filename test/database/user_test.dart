import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:homeworks/database/user.dart';

// Test naming scheme: should - when - given

void main() {
  group('FirestoreUser Tests', () {
    late FakeFirebaseFirestore mockFirestore;
    late FirestoreUser firestoreUser;

    const uid = 'test-user-id';

    setUp(() {
      mockFirestore = FakeFirebaseFirestore();
      firestoreUser = FirestoreUser(firestore: mockFirestore, uid: uid);
    });

    test('should create user document when it does not exist', () async {
      // test
      await firestoreUser.ensureDocumentExists();
      // verify
      final userDocAfter = await firestoreUser.userDocument.get();
      expect(userDocAfter.exists, isTrue);
    });

    test(
      'should preserve existing data when document already exists',
      () async {
        // setup
        await mockFirestore
            .collection(FirestoreUser.userCollection)
            .doc(uid)
            .set({'createdAt': 'now', 'isStillTheSame': true});
        // test
        await firestoreUser.ensureDocumentExists();
        // verify
        final userDocAfter = await firestoreUser.userDocument.get();
        expect(userDocAfter.exists, isTrue);
        expect(userDocAfter.data(), isNotNull);

        final userDocData = userDocAfter.data()!;
        expect(userDocData['isStillTheSame'], isTrue);
        expect(userDocData['createdAt'], equals('now'));
      },
    );

    test('should return correct document reference', () {
      // test
      final docRef = firestoreUser.userDocument;
      // verify
      expect(docRef.path, equals('${FirestoreUser.userCollection}/$uid'));
    });
  });
}
