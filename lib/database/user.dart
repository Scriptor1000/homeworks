import 'package:cloud_firestore/cloud_firestore.dart';

/// A helper class to manage a Firestore user document.
class FirestoreUser {
  /// The Firestore collection name where user documents are stored.
  static const userCollection = 'users';

  final FirebaseFirestore _firestore;
  final String _uid;

  /// Creates a [FirestoreUser] instance for a specific user [uid].
  ///
  /// Requires an instance of [FirebaseFirestore] to perform Firestore operations.
  FirestoreUser({required FirebaseFirestore firestore, required String uid})
    : _firestore = firestore,
      _uid = uid;

  /// Returns a reference to the Firestore document for this user.
  DocumentReference<Map<String, dynamic>> get userDocument =>
      _firestore.collection(userCollection).doc(_uid);

  /// Ensures that the user document exists in Firestore.
  ///
  /// If the document does not exist, it creates one with a `createdAt` timestamp.
  /// This is useful to initialize a user record on first login.
  Future<void> ensureDocumentExists() async {
    final userDoc = await userDocument.get();
    if (!userDoc.exists) {
      await userDocument.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}
