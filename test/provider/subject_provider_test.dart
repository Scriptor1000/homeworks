import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/models/subject.dart';
import 'package:homeworks/database/subjects.dart';
import 'package:homeworks/provider/subject_provider.dart';
import 'package:homeworks/provider/untis_provider.dart';
import 'package:homeworks/utilities/enums.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'subject_provider_test.mocks.dart';

Subject createMockSubject(int id, bool fromUntis, bool withNextLesson) {
  return Subject.fromDocument({
    'id': id,
    'fromUntis': fromUntis,
    'visible': true,
    'name': 'Subject $id',
    if (withNextLesson)
      'nextLesson': DateTime.now().add(Duration(days: id)).toIso8601String(),
  });
}

@GenerateNiceMocks([
  MockSpec<Subject>(),
  MockSpec<UntisProvider>(),
  MockSpec<FirestoreSubjects>()
])
void main() {
  group('Subject Provider:', () {
    late MockFirestoreSubjects mockFirestoreSubjects;
    late MockUntisProvider mockUntisProvider;
    late SubjectProvider subjectProvider;

    late List<Subject> firestoreSubjects;
    late List<Subject> untisSubjects;

    const int indexTillUntisSubjects = 4;

    setUp(() {
      mockFirestoreSubjects = MockFirestoreSubjects();
      mockUntisProvider = MockUntisProvider();

      subjectProvider =
          SubjectProvider(firestoreSubjects: mockFirestoreSubjects);

      firestoreSubjects = List.generate(
              6, (i) => createMockSubject(i, i < indexTillUntisSubjects, false))
          .toList();
      untisSubjects =
          List.generate(8, (i) => createMockSubject(i, true, true)).toList();

      when(mockFirestoreSubjects.loadAllUntisSubjects())
          .thenAnswer((_) async => firestoreSubjects);
      when(mockUntisProvider.untisSubjects).thenReturn(untisSubjects);
    });

    test('Initial values are correct', () {
      // verify
      expect(subjectProvider.subjects, isEmpty);
      expect(subjectProvider.untisSubjects, isEmpty);
      expect(subjectProvider.firestoreSubjectsLoaded, isFalse);
      expect(subjectProvider.untisSubjectStatus,
          equals(UntisSubjectStatus.untisUnavailable));
    });

    test('should load subjects from firestore on initialization', () async {
      // test
      await subjectProvider.initialize();
      // verify
      expect(subjectProvider.subjects, equals(firestoreSubjects));
      expect(subjectProvider.firestoreSubjectsLoaded, isTrue);
    });

    test('should add a new subject to firestore and memory ', () async {
      // setup
      final newSubject = MockSubject();
      when(newSubject.documentId).thenReturn('subject_new');
      // test
      await subjectProvider.addSubject(newSubject);
      // verify
      expect(subjectProvider.subjects.contains(newSubject), isTrue);
      verify(mockFirestoreSubjects.saveSubject(newSubject)).called(1);
    });

    test('should delete a subject from firestore and memory', () async {
      // setup
      final subjectToDelete = firestoreSubjects[0];
      await subjectProvider.initialize();
      // verify setup
      expect(subjectProvider.subjects, equals(firestoreSubjects));
      // test
      await subjectProvider.removeSubject(subjectToDelete);
      // verify
      expect(subjectProvider.subjects.contains(subjectToDelete), isFalse);
      verify(mockFirestoreSubjects.deleteSubject(subjectToDelete)).called(1);
    });

    test('should load untis subjects from untisProvider on update', () {
      // setup
      when(mockUntisProvider.untisSubjectStatus)
          .thenReturn(UntisSubjectStatus.loaded);
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(true);
      // test
      subjectProvider.updateUntisSubjects(mockUntisProvider);
      // verify
      expect(subjectProvider.untisSubjects, equals(untisSubjects));
      expect(subjectProvider.untisSubjectStatus,
          equals(UntisSubjectStatus.loaded));
    });

    test('should get and update the next lesson date from the untis subjects',
        () async {
      // setup
      when(mockUntisProvider.untisSubjectStatus)
          .thenReturn(UntisSubjectStatus.loaded);
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(true);
      await subjectProvider.initialize();
      // verify setup
      expect(subjectProvider.subjects, equals(firestoreSubjects));
      // test
      subjectProvider.updateUntisSubjects(mockUntisProvider);
      // verify
      for (int index = 0; index < indexTillUntisSubjects; index++) {
        final firestoreSubject = subjectProvider.subjects[index];
        final untisSubject = untisSubjects[index];
        expect(firestoreSubject.nextLesson, equals(untisSubject.nextLesson));
      }
      for (int index = indexTillUntisSubjects;
          index < firestoreSubjects.length;
          index++) {
        final firestoreSubject = firestoreSubjects[index];
        expect(firestoreSubject.nextLesson, isNull);
      }
    });

    test('should reset untis subjects when untisProvider removes them', () {
      // setup
      when(mockUntisProvider.untisSubjectStatus)
          .thenReturn(UntisSubjectStatus.loaded);
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(true);
      subjectProvider.updateUntisSubjects(mockUntisProvider);
      // verify setup
      expect(subjectProvider.untisSubjects, equals(untisSubjects));
      // change untisProvider to not loaded
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(false);
      when(mockUntisProvider.untisSubjectStatus)
          .thenReturn(UntisSubjectStatus.error);
      // test
      subjectProvider.updateUntisSubjects(mockUntisProvider);
      // verify
      expect(subjectProvider.untisSubjects, isEmpty);
      expect(
          subjectProvider.untisSubjectStatus, equals(UntisSubjectStatus.error));
    });

    test('should toggle visibility correctly on call', () async {
      // setup
      await subjectProvider.initialize();
      final subjectToToggle = firestoreSubjects[0];
      // verify setup
      expect(subjectProvider.subjects, equals(firestoreSubjects));
      // test
      await subjectProvider.toggleSubjectVisibility(subjectToToggle.documentId);
      // verify
      verify(mockFirestoreSubjects.saveSubject(subjectToToggle)).called(1);
      expect(subjectToToggle.visible, false);
    });

    test('get correct subject by untis id', () async {
      // setup
      await subjectProvider.initialize();
      final untisId = UntisElementDescriptor(UntisElementType.subject, 2);
      // test
      final subject = subjectProvider.getSubjectByUntisId(untisId);
      // verify
      expect(subject, isNotNull);
      expect(subject?.id, equals(2));
      expect(subject?.fromUntis, isTrue);
      expect(subject?.nextLesson, isNull);
    });

    test('should only get firestore subject by untis id', () async {
      // setup
      await subjectProvider.initialize();
      when(mockUntisProvider.untisSubjectStatus)
          .thenReturn(UntisSubjectStatus.loaded);
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(true);
      subjectProvider.updateUntisSubjects(mockUntisProvider);
      final untisId = UntisElementDescriptor(UntisElementType.subject, 7);
      // test
      final subject = subjectProvider.getSubjectByUntisId(untisId);
      // verify
      expect(subject, isNull);
    });

    test('should only get subjects from untis by untis id', () async {
      // setup
      await subjectProvider.initialize();
      final untisId = UntisElementDescriptor(
          UntisElementType.subject, indexTillUntisSubjects + 1);
      // test
      final subject = subjectProvider.getSubjectByUntisId(untisId);
      // verify
      expect(subject, isNull);
    });
  });
}
