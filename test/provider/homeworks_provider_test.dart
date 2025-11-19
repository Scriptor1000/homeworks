import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/homeworks.dart';
import 'package:homeworks/database/models/homework.dart';
import 'package:homeworks/database/models/subject.dart';
import 'package:homeworks/provider/homeworks_provider.dart';
import 'package:homeworks/provider/untis_provider.dart';
import 'package:homeworks/utilities/analytics_service.dart';
import 'package:homeworks/utilities/constants.dart';
import 'package:homeworks/utilities/enums.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'homeworks_provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirestoreHomeworks>(),
  MockSpec<AnalyticsService>(),
  MockSpec<UntisProvider>()
])
void main() {
  group('Homeworks Provider:', () {
    late MockFirestoreHomeworks mockFirestoreHomeworks;
    late MockAnalyticsService mockAnalyticsService;
    late HomeworksProvider homeworksProvider;

    final now = DateTime.now();
    const scanRange = Duration(days: 2);
    final afterRange = now.add(Duration(days: 3));
    final inRange = now.add(Duration(days: 1));
    final yesterday = now.subtract(Duration(days: 1));

    final inRangeNew = inRange.add(const Duration(hours: 12));
    final yesterdayNew = yesterday.add(const Duration(hours: 12));

    setUp(() {
      mockFirestoreHomeworks = MockFirestoreHomeworks();
      mockAnalyticsService = MockAnalyticsService();
      homeworksProvider = HomeworksProvider(
          firestoreHomeworks: mockFirestoreHomeworks,
          analyticsService: mockAnalyticsService);
    });

    final toDeleteHomeworks = [
      Homework(
          id: '1',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: false,
          dueDate: now.add(const Duration(days: 1)),
          fromUntis: false),
      Homework(
          id: '2',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: false,
          dueDate: now.subtract(const Duration(days: 1)),
          fromUntis: false),
      Homework(
          id: '3',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: true,
          dueDate: now.add(const Duration(days: 1)),
          fromUntis: false),
      Homework(
          id: '4',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: true,
          dueDate: now.subtract(const Duration(days: 1)),
          fromUntis: false),
      Homework(
          id: '5',
          title: 'title',
          description: 'des',
          subjectDocId: 'untis',
          toNextLesson: true,
          isCompleted: true,
          dueDate: now.subtract(const Duration(days: 1)),
          fromUntis: false),
    ];

    test('should load and delete old Homeworks on initialisation', () async {
      // setup
      when(mockFirestoreHomeworks.loadAllHomeworks())
          .thenAnswer((_) async => toDeleteHomeworks);
      // test
      await homeworksProvider.initialize();
      // verify
      expect(homeworksProvider.homeworks.length, equals(3));
      expect(homeworksProvider.homeworksLoaded, isTrue);
      verify(mockFirestoreHomeworks.deleteHomework('4')).called(1);
      verify(mockFirestoreHomeworks.deleteHomework('5')).called(1);
      verify(mockFirestoreHomeworks.loadAllHomeworks()).called(1);
      verifyNoMoreInteractions(mockFirestoreHomeworks);
    });

    test(
        'should update due dates only when toNextLesson, not fromUntis, after now and in range',
        () async {
      // setup
      when(mockFirestoreHomeworks.loadAllHomeworks()).thenAnswer((_) {
        final afterRange = now.add(const Duration(days: 1)).add(scanRange);
        final inRange = now.add(Duration(hours: scanRange.inHours ~/ 2));
        final yesterday = now.subtract(const Duration(days: 1));

        final data = [
          HomeworkData(
              dueDate: yesterday,
              toNextLesson: true,
              fromUntis: false), // 0 not to update (because before now)
          HomeworkData(
              dueDate: inRange,
              toNextLesson: true,
              fromUntis: true), // 1 not to update (because fromUntis)
          HomeworkData(
              dueDate: inRange,
              toNextLesson: false,
              fromUntis: false), // 2 not to update (because not toNextLesson)
          HomeworkData(
              dueDate: afterRange,
              toNextLesson: true,
              fromUntis:
                  false), // 3 not to update (because after range and not found)
          HomeworkData(
              dueDate: afterRange,
              toNextLesson: true,
              fromUntis: false), // 4 to update (because found in range)
          HomeworkData(
              dueDate: inRange,
              toNextLesson: true,
              fromUntis: false), // 5 to update (reset because not found)
          HomeworkData(
              dueDate: inRange,
              toNextLesson: true,
              fromUntis: false), // 6 to update (because found)
        ];

        List<Homework> homeworks = [];
        for (var i = 0; i < data.length; i++) {
          homeworks.add(Homework(
              id: '$i',
              title: 'title',
              description: 'des',
              subjectDocId: 'untis_$i',
              toNextLesson: data[i].toNextLesson,
              isCompleted: false,
              dueDate: data[i].dueDate,
              fromUntis: data[i].fromUntis));
        }
        return Future.value(homeworks);
      });
      final mockUntisProvider = MockUntisProvider();
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(true);
      when(mockUntisProvider.endDate).thenReturn(now.add(scanRange));
      when(mockUntisProvider.getNextLessonDates()).thenReturn({
        'untis_0': yesterdayNew,
        'untis_1': inRangeNew,
        'untis_2': inRangeNew,
        'untis_4': inRangeNew,
        'untis_6': inRangeNew,
      });

      await homeworksProvider.initialize();
      // verify setup
      expect(homeworksProvider.homeworks.length, equals(7));
      expect(homeworksProvider.homeworksLoaded, isTrue);
      verify(mockFirestoreHomeworks.loadAllHomeworks()).called(1);
      // test
      await homeworksProvider.updateDueDates(mockUntisProvider);
      // verify
      final homeworks = homeworksProvider.homeworks;
      expect(homeworks[0].dueDate, equals(yesterday),
          reason:
              'A homework wich is from the past should not be updated'); // not to update
      expect(homeworks[1].dueDate, equals(inRange),
          reason:
              'A homework wich is imported from untis should be ignored'); // not to update
      expect(homeworks[2].dueDate, equals(inRange),
          reason:
              'Only Homeworks wich are marked to next lesson should be updated'); // not to update
      expect(homeworks[3].dueDate, equals(afterRange),
          reason:
              'A Homework wich due date lies not in scan range and no earlier lesson is found should not be updated'); // not to update
      expect(homeworks[4].dueDate, equals(inRangeNew),
          reason:
              'A due date should be updated if an earlier lesson is found, even if the original due date lies int in scan range'); // to update
      expect(homeworks[5].dueDate, isNull,
          reason:
              'A due date should be set to null if no lesson was found in the scan range and no other due date is known'); // to update (reset)
      expect(homeworks[6].dueDate, equals(inRangeNew),
          reason:
              'A due date should be updated when a new due date is found and it is marked as to next lesson'); // to update
      verify(mockFirestoreHomeworks.saveHomework(homeworks[4])).called(1);
      verify(mockFirestoreHomeworks.saveHomework(homeworks[5])).called(1);
      verify(mockFirestoreHomeworks.saveHomework(homeworks[6])).called(1);
      verify(mockAnalyticsService.updateDueDates(3)).called(1);
      verify(mockUntisProvider.untisSubjectsLoaded).called(1);
      verify(mockUntisProvider.getNextLessonDates()).called(1);
      verifyNoMoreInteractions(mockFirestoreHomeworks);
    });

    test('should not update due dates if subject loading is not completed',
        () async {
      // setup
      when(mockFirestoreHomeworks.loadAllHomeworks())
          .thenAnswer((_) async => toDeleteHomeworks);
      final mockUntisProvider = MockUntisProvider();
      when(mockUntisProvider.untisSubjectsLoaded).thenReturn(false);

      await homeworksProvider.initialize();
      // verify setup
      expect(homeworksProvider.homeworks.length, equals(3));
      expect(homeworksProvider.homeworksLoaded, isTrue);
      verify(mockFirestoreHomeworks.loadAllHomeworks()).called(1);
      // test
      await homeworksProvider.updateDueDates(mockUntisProvider);
      // verify
      verify(mockUntisProvider.untisSubjectsLoaded).called(1);
      verifyNever(mockUntisProvider.getNextLessonDates());
      verifyNoMoreInteractions(mockUntisProvider);
      verifyNoMoreInteractions(mockFirestoreHomeworks);
    });

    Future<Homework> oneHomeworkTestSetup(
        {bool? completed, DateTime? dueDate}) async {
      final Homework homework = Homework(
          id: '1',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: completed ?? false,
          dueDate: dueDate ?? now.add(const Duration(days: 1)),
          fromUntis: false);
      when(mockFirestoreHomeworks.loadAllHomeworks())
          .thenAnswer((_) async => [homework]);
      await homeworksProvider.initialize();
      // verify setup
      expect(homeworksProvider.homeworks.length, equals(1));
      expect(homeworksProvider.homeworksLoaded, isTrue);
      verify(mockFirestoreHomeworks.loadAllHomeworks()).called(1);

      return homework;
    }

    test('should update due date in memory and in database', () async {
      // setup
      final homework = await oneHomeworkTestSetup(dueDate: now);
      final dueDate = now.add(const Duration(days: 5));
      // test
      await homeworksProvider.newDueDate(homework.id, dueDate);
      // verify
      expect(homeworksProvider.homeworks[0].dueDate, equals(dueDate));
      // the original homework was given as reference and is updated too
      expect(homework.dueDate, equals(dueDate));
      verify(mockFirestoreHomeworks.saveHomework(homework)).called(1);
      verify(mockAnalyticsService.reviveHomework(type: homework.type))
          .called(1);
    });

    test(
        'should not throw an error if no homework to update due date was found',
        () {
      // setup
      final homework = Homework(
          id: '1',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: false,
          dueDate: now,
          fromUntis: false);
      final dueDate = now.add(const Duration(days: 5));
      // test
      expect(homeworksProvider.newDueDate(homework.id, dueDate), completes);
      // verify
      verifyNever(mockFirestoreHomeworks.saveHomework(homework));
      verifyNever(
          mockAnalyticsService.reviveHomework(type: HomeworkType.homework));
    });

    test('should create Homework just with current Subject', () async {
      // setup
      final testSubject = Subject.fromDocument({
        'backColor': 0x00000000,
        'foreColor': 0x00000000,
        'id': 42,
        'fromUntis': true,
        'name': 'Mathematik',
        'shortName': 'M'
      });
      // test
      await homeworksProvider.fastCreateHomework('LB.S.pi/e', testSubject);
      // verify
      expect(homeworksProvider.homeworks.length, equals(1));
      final homework = homeworksProvider.homeworks[0];
      expect(homework.subjectDocId, equals('untis_42'));
      expect(homework.title, equals('LB.S.pi/e'));
      verify(mockFirestoreHomeworks.saveHomework(homework)).called(1);
      verify(mockAnalyticsService.createHomework(
              type: HomeworkType.homework,
              isToNextLesson: true,
              isCreatedFast: true))
          .called(1);
    });

    test('should recognize a test by prefixes', () async {
      // setup
      final testSubject = Subject.fromDocument({
        'backColor': 0x00000000,
        'foreColor': 0x00000000,
        'id': 42,
        'fromUntis': true,
        'name': 'Mathematik',
        'shortName': 'M'
      });
      final prefixes = examPrefixes;
      // test
      for (final prefix in prefixes) {
        await homeworksProvider.fastCreateHomework(
            '$prefix irgendwas', testSubject);
      }
      // verify
      expect(homeworksProvider.homeworks.length, equals(prefixes.length));
      for (final homework in homeworksProvider.homeworks) {
        expect(homework.subjectDocId, equals('untis_42'));
        expect(homework.title, equals('irgendwas'));
        expect(homework.type, equals(HomeworkType.exam));
        verify(mockFirestoreHomeworks.saveHomework(homework)).called(1);
      }
      verify(mockAnalyticsService.createHomework(
              type: HomeworkType.exam,
              isToNextLesson: true,
              isCreatedFast: true))
          .called(prefixes.length);
    });

    test('should save homework in memory and in database', () async {
      // setup
      final Homework homework = Homework(
          id: '1',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: false,
          dueDate: now,
          fromUntis: false);
      // test
      await homeworksProvider.createHomework(homework);
      // verify
      expect(homeworksProvider.homeworks.length, equals(1));
      expect(homeworksProvider.homeworks[0], equals(homework));
      verify(mockFirestoreHomeworks.saveHomework(homework)).called(1);
    });

    test('should complete homework in memory and in database', () async {
      // setup
      final homework = await oneHomeworkTestSetup();
      // test
      await homeworksProvider.toggleHomeworkCompletion(homework.id);
      // verify
      expect(homeworksProvider.homeworks.length, equals(1));
      expect(homeworksProvider.homeworks[0].isCompleted, isTrue);
      verify(mockFirestoreHomeworks.saveHomework(homework)).called(1);
      verify(mockAnalyticsService.completeHomework(
              type: homework.type, isPastDueBy: anyNamed('isPastDueBy')))
          .called(1);
    });

    test('should delete past due homework when it is completed', () async {
      // setup
      final homework = await oneHomeworkTestSetup(
          dueDate: now.subtract(const Duration(days: 1)));
      // test
      await homeworksProvider.toggleHomeworkCompletion(homework.id);
      // verify
      expect(homeworksProvider.homeworks.length, equals(0));
      verify(mockFirestoreHomeworks.deleteHomework(homework.documentId))
          .called(1);
      verify(mockAnalyticsService.completeAndDeleteHomework(
              type: homework.type, isPastDueBy: anyNamed('isPastDueBy')))
          .called(1);
    });

    test('should not throw an error if no homework was found to complete',
        () async {
      // test
      expect(homeworksProvider.toggleHomeworkCompletion('not existent id'),
          completes);
      // verify
      verifyZeroInteractions(mockFirestoreHomeworks);
      verifyZeroInteractions(mockAnalyticsService);
    });

    test('should uncomplete an already completed homework', () async {
      // setup
      final homework = await oneHomeworkTestSetup(completed: true);
      // test
      await homeworksProvider.toggleHomeworkCompletion(homework.id);
      // verify
      expect(homeworksProvider.homeworks.length, equals(1));
      expect(homeworksProvider.homeworks[0].isCompleted, isFalse);
      verify(mockFirestoreHomeworks.saveHomework(homework)).called(1);
      verify(mockAnalyticsService.uncompleteHomework(
              type: homework.type, isDueIn: anyNamed('isDueIn')))
          .called(1);
    });

    test('should delete a homework from memory and database', () async {
      // setup
      final Homework homework = Homework(
          id: '1',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: false,
          dueDate: now,
          fromUntis: false);
      when(mockFirestoreHomeworks.loadAllHomeworks())
          .thenAnswer((_) async => [homework]);
      await homeworksProvider.initialize();
      // verify setup
      expect(homeworksProvider.homeworks.length, equals(1));
      expect(homeworksProvider.homeworksLoaded, isTrue);
      verify(mockFirestoreHomeworks.loadAllHomeworks()).called(1);
      // test
      await homeworksProvider.deleteHomework(homework.id);
      // verify
      expect(homeworksProvider.homeworks.length, equals(0));
      verify(mockFirestoreHomeworks.deleteHomework(homework.documentId))
          .called(1);
      verify(mockAnalyticsService.deleteHomework(
          type: homework.type,
          isPastDueBy: anyNamed('isPastDueBy'),
          isCompleted: homework.isCompleted));
    });

    test('should not throw an error if no homework was found to delete', () {
      // setup
      final Homework homework = Homework(
          id: '1',
          title: 'title',
          description: 'des',
          subjectDocId: 'sub',
          toNextLesson: false,
          isCompleted: false,
          dueDate: now,
          fromUntis: false);
      // test
      expect(homeworksProvider.deleteHomework(homework.id), completes);
      // verify
      verifyNever(mockFirestoreHomeworks.deleteHomework(homework.documentId));
      verifyZeroInteractions(mockAnalyticsService);
    });
  });
}

class HomeworkData {
  final DateTime dueDate;
  final bool toNextLesson;
  final bool fromUntis;

  HomeworkData(
      {required this.dueDate,
      required this.toNextLesson,
      required this.fromUntis});
}
