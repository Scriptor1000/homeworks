import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/database/homeworks.dart';
import 'package:homeworks/database/models/homework.dart';
import 'package:homeworks/provider/homeworks_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'homeworks_provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirestoreHomeworks>(),
])
void main() {
  group('Homeworks Provider:', () {
    late FirestoreHomeworks mockFirestoreHomeworks;
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
      homeworksProvider =
          HomeworksProvider(firestoreHomeworks: mockFirestoreHomeworks);
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
      final nextLessonDates = {
        'untis_0': yesterdayNew,
        'untis_1': inRangeNew,
        'untis_2': inRangeNew,
        'untis_4': inRangeNew,
        'untis_6': inRangeNew,
      };

      await homeworksProvider.initialize();
      // verify setup
      expect(homeworksProvider.homeworks.length, equals(7));
      expect(homeworksProvider.homeworksLoaded, isTrue);
      verify(mockFirestoreHomeworks.loadAllHomeworks()).called(1);
      // test
      await homeworksProvider.updateDueDates(
          nextLessonDates, now.add(scanRange));
      // verify
      final homeworks = homeworksProvider.homeworks;
      expect(homeworks[0].dueDate, equals(yesterday)); // not to update
      expect(homeworks[1].dueDate, equals(inRange)); // not to update
      expect(homeworks[2].dueDate, equals(inRange)); // not to update
      expect(homeworks[3].dueDate, equals(afterRange)); // not to update
      expect(homeworks[4].dueDate, equals(inRangeNew)); // to update
      expect(homeworks[5].dueDate, isNull); // to update (reset)
      expect(homeworks[6].dueDate, equals(inRangeNew)); // to update
      verify(mockFirestoreHomeworks.saveHomework(homeworks[4])).called(1);
      verify(mockFirestoreHomeworks.saveHomework(homeworks[5])).called(1);
      verify(mockFirestoreHomeworks.saveHomework(homeworks[6])).called(1);
      verifyNoMoreInteractions(mockFirestoreHomeworks);
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
