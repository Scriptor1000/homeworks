import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/factory.dart';
import 'models/subject.dart';
import 'user.dart';

/// Class for handling subjects in Firestore with dependency injections.
class FirestoreSubjects {
  static const subjectCollection = 'subjects';

  final FirestoreUser _firestoreUser;
  final ItemFactory _itemFactory;

  FirestoreSubjects({
    required FirestoreUser firestoreUser,
    required ItemFactory itemFactory,
  })  : _firestoreUser = firestoreUser,
        _itemFactory = itemFactory;

  CollectionReference<Map<String, dynamic>> get _subjectCollectionRef =>
      _firestoreUser.userDocument.collection(subjectCollection);

  /// Speichert das [subject] in Firestore.
  ///
  /// Lädt das [subject] in die [subjectCollection] des aktuellen Benutzers hoch.
  /// Wenn ein Dokument mit derselben ID bereits vorhanden ist, werden die Daten zusammengeführt.
  Future<void> saveSubject(Subject subject) async {
    await _subjectCollectionRef
        .doc(subject.documentId)
        .set(subject.toDocument(), SetOptions(merge: true));
  }

  /// Lädt ein Fach anhand seiner Dokumenten-ID aus Firestore.
  ///
  /// Gibt ein [Subject]-Objekt zurück, wenn das Dokument in [subjectCollection] vorhanden ist, andernfalls null.
  Future<Subject?> loadSubject(String documentId) async {
    final doc = await _subjectCollectionRef.doc(documentId).get();

    if (doc.exists) {
      return _itemFactory.subjectFromDocument(doc.data()!);
    }

    return null;
  }

  /// Lädt alle Fächer aus Firestore.
  ///
  /// Gibt eine Liste von [Subject]-Objekten zurück, die in [subjectCollection] gespeichert sind.
  Future<List<Subject>> loadAllSubjects() async {
    final snapshot = await _subjectCollectionRef.get();

    return snapshot.docs
        .map((doc) => _itemFactory.subjectFromDocument(doc.data()))
        .toList();
  }

  /// Löscht ein Fach aus Firestore.
  ///
  /// Entfernt das Dokument von [subject] aus der [subjectCollection] von Firestore.
  Future<void> deleteSubject(Subject subject) async {
    print('Deleting subject: ${subject.documentId}');

    await _subjectCollectionRef.doc(subject.documentId).delete();
  }

  /// Lädt alle Fächer, die aus Untis importiert wurden, aus Firestore.
  ///
  /// Gibt eine Liste von [Subject]-Objekten zurück, die das Feld 'fromUntis'
  /// auf true gesetzt haben und in der [subjectCollection] gespeichert sind.
  Future<List<Subject>> loadAllUntisSubjects() async {
    final snapshot =
        await _subjectCollectionRef.where('fromUntis', isEqualTo: true).get();

    final List<Subject> subjects = [
      for (var doc in snapshot.docs)
        _itemFactory.subjectFromDocument(doc.data())
    ];

    return subjects;
  }
}
