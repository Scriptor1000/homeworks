import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/factory.dart';
import 'models/homework.dart';
import 'user.dart';

/// Klasse für das Handling von Homeworks in Firestore mit Dependency Injection.
class FirestoreHomeworks {
  static const String homeworksCollections = 'homeworks';

  final FirestoreUser _firestoreUser;
  final ItemFactory _itemFactory;

  FirestoreHomeworks({
    required FirestoreUser firestoreUser,
    required ItemFactory itemFactory,
  })  : _firestoreUser = firestoreUser,
        _itemFactory = itemFactory;

  CollectionReference<Map<String, dynamic>> get _homeworksCollectionsRef =>
      _firestoreUser.userDocument.collection(homeworksCollections);

  /// Saves the homework to Firestore.
  ///
  /// Uploads the [homework] to the [homeworksCollections] of the current user.
  /// If a document with the same ID already exists, it merges the data.
  Future<void> saveHomework(Homework homework) async {
    await _homeworksCollectionsRef
        .doc(homework.documentId)
        .set(homework.toDocument(), SetOptions(merge: true));
  }

  /// Loads all homeworks from Firestore.
  ///
  /// Retrieves all homework documents from the current user's [homeworksCollections]
  /// and converts them to a list of [Homework] objects.
  Future<List<Homework>> loadAllHomeworks() async {
    final snapshot = await _homeworksCollectionsRef.get();
    return [
      for (var doc in snapshot.docs)
        _itemFactory.homeworkFromDocument(doc.data())
    ];
  }

  /// Deletes all Homeworks wich are done and are due before now.
  Future<void> deleteCompletedHomeworks() async {
    final now = DateTime.now();
    final snapshot = await _homeworksCollectionsRef
        .where('done', isEqualTo: true)
        .where('dueDate', isLessThan: now)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Deletes a homework from Firestore.
  ///
  /// Deletes the homework with the given [homeworkDocId] from the current user's
  /// [homeworksCollections].
  Future<void> deleteHomework(String homeworkDocId) async {
    await _homeworksCollectionsRef.doc(homeworkDocId).delete();
  }
}
