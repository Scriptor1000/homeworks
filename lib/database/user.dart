import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUser {
  static const userCollection = 'users';

  final FirebaseFirestore _firestore;
  final String _uid;

  FirestoreUser({required FirebaseFirestore firestore, required String uid})
    : _firestore = firestore,
      _uid = uid;

  DocumentReference<Map<String, dynamic>> get userDocument =>
      _firestore.collection(userCollection).doc(_uid);

  /// Ensures that the user document exists in Firestore.
  ///
  /// If the document does not exist, it creates one with a timestamp.
  Future<void> ensureDocumentExists() async {
    final userDoc = await userDocument.get();
    if (!userDoc.exists) {
      await userDocument.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}
