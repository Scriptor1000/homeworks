import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/allowed_emails.dart';

void main() {
  group('AllowedUser Tests', () {
    late FakeFirebaseFirestore mockFirestore;
    late FirestoreAllowedEmails firestoreAllowedEmails;

    const uid = 'test-user-id';
    const validEmail = 'user@tester.de';
    const invalidEmail = 'not@Allowed.mail';

    setUp(() {
      mockFirestore = FakeFirebaseFirestore();
      firestoreAllowedEmails = FirestoreAllowedEmails(firestore: mockFirestore);
    });

    test(
        'should return true when email exists in the allowed emails collection',
        () async {
      // setup
      await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .doc('test_123')
          .set({FirestoreAllowedEmails.emailField: validEmail});
      // test
      final isAllowed = await firestoreAllowedEmails.isEmailAllowed(validEmail);
      // verify
      expect(isAllowed, isTrue);
    });

    test(
        'should return false when email does not exists in the allowed emails collection',
        () async {
      // test
      final isNotAllowed =
          await firestoreAllowedEmails.isEmailAllowed(invalidEmail);
      // verify
      expect(isNotAllowed, isFalse);
    });

    test('should replace temporary entries with document with uid as name',
        () async {
      // setup
      await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .doc('temp_autorization')
          .set({FirestoreAllowedEmails.emailField: validEmail});
      await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .doc('temp_autorization_2')
          .set({FirestoreAllowedEmails.emailField: validEmail});
      // test
      await firestoreAllowedEmails.removeTemporaryEntries(validEmail, uid);
      // verify
      final snapshot = await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .get();

      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.id, equals(uid));
      expect(snapshot.docs.first.data(),
          equals({FirestoreAllowedEmails.emailField: validEmail}));
    });

    test('should create a document with uid and email to authorize an email',
        () async {
      // test
      await firestoreAllowedEmails.authorizeEmail(validEmail, uid);
      // verify
      final doc = await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .doc(uid)
          .get();

      expect(doc.exists, isTrue);
      expect(
          doc.data(), equals({FirestoreAllowedEmails.emailField: validEmail}));
    });

    test('should delete the document with the uid to revoke an email',
        () async {
      // setup
      await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .doc(uid)
          .set({FirestoreAllowedEmails.emailField: validEmail});
      // test
      await firestoreAllowedEmails.revokeEmail(uid);
      // verify
      final docRef = await mockFirestore
          .collection(FirestoreAllowedEmails.emailsCollection)
          .doc(uid)
          .get();

      expect(docRef.exists, isFalse);
    });
  });
}
