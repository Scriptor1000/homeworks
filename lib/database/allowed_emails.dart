import 'package:cloud_firestore/cloud_firestore.dart';

/// Static class for handling allowed emails in Firestore.
class FirestoreAllowedEmails {
  // Removed static uid field to avoid conflict with instance field.

  static const String emailsCollection = 'allowed_emails';
  static const String emailField = 'email';

  final FirebaseFirestore _firestore;

  FirestoreAllowedEmails({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get emailsCollectionRef =>
      _firestore.collection(emailsCollection);

  /// Whether the given email is on the allowed list.
  ///
  /// A email is allowed if one document  exists in the Firestore collection
  /// wich contains this email. It is not necessary the doucment of the associated user.
  Future<bool> isEmailAllowed(String email) async {
    final snapshot =
        await emailsCollectionRef.where(emailField, isEqualTo: email).get();

    return snapshot.docs.isNotEmpty;
  }

  /// Removes temporary entries for the given email.
  ///
  /// Removes all entries with the given email except the one with the current user's UID.
  /// If no entry with the UID exists, it creates one with the email.
  Future<void> removeTemporaryEntries(String email, String uid) async {
    final collectionRef =
        emailsCollectionRef.where(emailField, isEqualTo: email);

    final snapshot = await collectionRef.get();
    bool docWithUIDExists = false;
    for (final doc in snapshot.docs) {
      if (doc.id != uid) {
        await doc.reference.delete();
      } else {
        docWithUIDExists = true;
      }
    }
    if (!docWithUIDExists) {
      await emailsCollectionRef
          .doc(uid)
          .set({emailField: email}, SetOptions(merge: true));
    }
  }

  /// Authorizes the email for the current user.
  Future<void> authorizeEmail(String email, String uid) async {
    final doc = emailsCollectionRef.doc(uid);
    await doc.set({emailField: email}, SetOptions(merge: true));
  }

  /// Revokes the email for the current user.
  ///
  /// Deletes the document for the current user in wich the email is stored.
  /// Does not delete other documents wich could contain the same email.
  Future<void> revokeEmail(String uid) async {
    final doc = emailsCollectionRef.doc(uid);
    await doc.delete();
  }
}
