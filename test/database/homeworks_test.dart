import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/homeworks.dart';
import 'package:homeworks/database/models/factory.dart';
import 'package:homeworks/database/models/homework.dart';
import 'package:homeworks/database/user.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'homeworks_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirestoreUser>(),
  MockSpec<Homework>(),
  MockSpec<ItemFactory>(),
])
void main() {
  group('Homeworks storage tests', () {
    late FirestoreUser mockFirestoreUser;
    late FakeFirebaseFirestore mockFirestore;
    late ItemFactory mockItemFactory;
    late FirestoreHomeworks firestoreHomeworks;

    late List<Homework> mockHomeworks;

    const String uid = 'test-uid';

    final now = DateTime.now();

    setUp(() {
      mockFirestore = FakeFirebaseFirestore();
      mockFirestoreUser = MockFirestoreUser();
      mockItemFactory = MockItemFactory();
      firestoreHomeworks = FirestoreHomeworks(
        firestoreUser: mockFirestoreUser,
        itemFactory: mockItemFactory,
      );

      mockHomeworks = List.generate(4, (_) => MockHomework());

      when(mockFirestoreUser.userDocument).thenReturn(
          mockFirestore.collection(FirestoreUser.userCollection).doc(uid));

      for (var i = 0; i < mockHomeworks.length; i++) {
        when(mockHomeworks[i].documentId).thenReturn('homework-$i');
        when(mockHomeworks[i].toDocument()).thenReturn({
          'homeworkId': i,
          'done': i % 2 == 0,
          'dueDate': i < 2
              ? Timestamp.fromDate(now.add(Duration(days: 2)))
              : Timestamp.fromDate(now.subtract(Duration(days: 2))),
        });
        when(mockItemFactory.homeworkFromDocument({
          'homeworkId': i,
          'done': i % 2 == 0,
          'dueDate': i < 2
              ? Timestamp.fromDate(now.add(Duration(days: 2)))
              : Timestamp.fromDate(now.subtract(Duration(days: 2))),
        })).thenReturn(mockHomeworks[i]);
      }
    });

    test('should save homework correctly', () async {
      // test
      firestoreHomeworks.saveHomework(mockHomeworks[0]);
      // verify
      final collection = await mockFirestoreUser.userDocument
          .collection(FirestoreHomeworks.homeworksCollections)
          .get();
      expect(collection.docs.length, equals(1));
      expect(
          collection.docs.first.data(), equals(mockHomeworks[0].toDocument()));
    });

    test('should load all homeworks', () async {
      // setup
      for (var homework in mockHomeworks) {
        await mockFirestoreUser.userDocument
            .collection(FirestoreHomeworks.homeworksCollections)
            .doc(homework.documentId)
            .set(homework.toDocument());
      }
      // test
      final loadedHomeworks = await firestoreHomeworks.loadAllHomeworks();
      // verify
      expect(loadedHomeworks.length, equals(mockHomeworks.length));
      for (var i = 0; i < mockHomeworks.length; i++) {
        expect(
            loadedHomeworks[i].documentId, equals(mockHomeworks[i].documentId));
      }
    });

    test('should delete only completed homeworks', () async {
      // setup
      for (var homework in mockHomeworks) {
        await mockFirestoreUser.userDocument
            .collection(FirestoreHomeworks.homeworksCollections)
            .doc(homework.documentId)
            .set(homework.toDocument());
      }
      // test
      await firestoreHomeworks.deleteCompletedHomeworks();
      // verify
      final collection = await mockFirestoreUser.userDocument
          .collection(FirestoreHomeworks.homeworksCollections)
          .get();
      expect(collection.docs.length, equals(3));
      final ids = collection.docs.map((doc) => doc.id).toList();
      expect(ids, contains('homework-0')); // done +2d
      expect(ids, contains('homework-1')); // not done +2d
      expect(ids, isNot(contains('homework-2'))); // done -2d
      expect(ids, contains('homework-3')); // not done -2d
    });

    test('should delete homework', () async {
      // setup
      final homeworkToDelete = mockHomeworks[0];
      await mockFirestoreUser.userDocument
          .collection(FirestoreHomeworks.homeworksCollections)
          .doc(homeworkToDelete.documentId)
          .set(homeworkToDelete.toDocument());
      // test
      await firestoreHomeworks.deleteHomework(homeworkToDelete.documentId);
      // verify
      final collection = await mockFirestoreUser.userDocument
          .collection(FirestoreHomeworks.homeworksCollections)
          .get();
      expect(collection.docs.length, equals(0));
    });
  });
}
