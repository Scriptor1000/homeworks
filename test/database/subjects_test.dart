import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/models/factory.dart';
import 'package:homeworks/database/models/subject.dart';
import 'package:homeworks/database/subjects.dart';
import 'package:homeworks/database/user.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'subjects_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirestoreUser>(),
  MockSpec<ItemFactory>(),
  MockSpec<Subject>(),
])
void main() {
  group('Subjects storage tests', () {
    late FirestoreUser mockFirestoreUser;
    late FakeFirebaseFirestore mockFirestore;
    late ItemFactory itemFactory;
    late FirestoreSubjects firestoreSubjects;

    late List<Subject> subjects;

    const String uid = 'test-uid';

    setUp(() {
      mockFirestore = FakeFirebaseFirestore();
      mockFirestoreUser = MockFirestoreUser();
      itemFactory = MockItemFactory();
      firestoreSubjects = FirestoreSubjects(
        firestoreUser: mockFirestoreUser,
        itemFactory: itemFactory,
      );

      when(mockFirestoreUser.userDocument).thenReturn(
        mockFirestore.collection(FirestoreUser.userCollection).doc(uid),
      );

      subjects = List.generate(4, (_) => MockSubject());

      for (var i = 0; i < subjects.length; i++) {
        final fromUntis = i % 2 == 0;
        when(subjects[i].documentId)
            .thenReturn('${fromUntis ? 'untis_' : 'custom_'}$i');
        when(subjects[i].toDocument()).thenReturn({
          'id': i,
          'fromUntis': fromUntis,
        });
        when(itemFactory.subjectFromDocument({
          'id': i,
          'fromUntis': fromUntis,
        })).thenReturn(subjects[i]);
      }
    });

    test('should save subject correctly', () async {
      // test
      await firestoreSubjects.saveSubject(subjects[0]);
      // verify
      final collection = await mockFirestoreUser.userDocument
          .collection(FirestoreSubjects.subjectCollection)
          .get();
      expect(collection.docs.length, 1);
      expect(collection.docs.first.data(), subjects[0].toDocument());
    });

    test('should load subject by id (existing)', () async {
      // setup
      await mockFirestoreUser.userDocument
          .collection(FirestoreSubjects.subjectCollection)
          .doc(subjects[0].documentId)
          .set(subjects[0].toDocument());
      // test
      final loaded =
          await firestoreSubjects.loadSubject(subjects[0].documentId);
      // verify
      expect(loaded, isNotNull);
      expect(loaded!, equals(subjects[0]));
    });

    test('should return null when loading non-existent subject', () async {
      // test
      final loaded = await firestoreSubjects.loadSubject('missing-id');
      // verify
      expect(loaded, isNull);
    });

    test('should load all subjects', () async {
      // setup
      for (var subject in subjects) {
        await mockFirestoreUser.userDocument
            .collection(FirestoreSubjects.subjectCollection)
            .doc(subject.documentId)
            .set(subject.toDocument());
      }
      // test
      final loadedSubjects = await firestoreSubjects.loadAllSubjects();
      // verify
      expect(loadedSubjects.length, equals(subjects.length));
      final loadedIds = loadedSubjects.map((s) => s.documentId).toSet();
      final expectedIds = subjects.map((s) => s.documentId).toSet();
      expect(loadedIds, equals(expectedIds));
    });

    test('should delete subject', () async {
      // setup
      final subjectToDelete = subjects[0];
      await mockFirestoreUser.userDocument
          .collection(FirestoreSubjects.subjectCollection)
          .doc(subjectToDelete.documentId)
          .set(subjectToDelete.toDocument());
      // test
      await firestoreSubjects.deleteSubject(subjectToDelete);
      // verify
      final collection = await mockFirestoreUser.userDocument
          .collection(FirestoreSubjects.subjectCollection)
          .get();
      expect(collection.docs.length, equals(0));
    });

    test('should load all Untis subjects only (fromUntis == true)', () async {
      // setup
      for (var subject in subjects) {
        await mockFirestoreUser.userDocument
            .collection(FirestoreSubjects.subjectCollection)
            .doc(subject.documentId)
            .set(subject.toDocument());
      }
      // test
      final untisSubjects = await firestoreSubjects.loadAllUntisSubjects();
      // verify
      expect(untisSubjects.length, equals(2));
      expect(untisSubjects.every((s) => s.documentId.startsWith('untis_')),
          isTrue);
    });
  });
}
