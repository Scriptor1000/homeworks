import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeworks/provider/untis_provider.dart';
import 'package:homeworks/utilities/enums.dart' hide test;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'untis_provider_test.mocks.dart';

MockUntisPeriod createMockUntisPeriod({
  String? subjectName,
  required bool isCancelled,
  required bool withTeacher,
  required DateTime start,
}) {
  final mockPeriod = MockUntisPeriod();
  when(mockPeriod.isCancelled).thenReturn(isCancelled);
  when(mockPeriod.startDateTime).thenReturn(start);
  when(mockPeriod.endDateTime)
      .thenReturn(start.add(const Duration(minutes: 45)));

  if (subjectName != null) {
    final mockSubject = MockUntisSubject();
    when(mockSubject.name).thenReturn(subjectName);
    when(mockSubject.longName).thenReturn(subjectName);
    when(mockSubject.id).thenReturn(
        UntisElementDescriptor(UntisElementType.subject, subjectName.hashCode));
    when(mockPeriod.subject).thenReturn(mockSubject);
  }

  if (withTeacher) {
    when(mockPeriod.teacher).thenReturn(MockUntisTeacher());
  }

  return mockPeriod;
}

@GenerateNiceMocks([
  MockSpec<UntisSession>(),
  MockSpec<UntisTimetable>(),
  MockSpec<UntisPeriod>(),
  MockSpec<UntisSubject>(),
  MockSpec<UntisTeacher>(),
])
void main() {
  group('Untis Provider ', () {
    late MockUntisSession mockUntisSession;
    late UntisProvider untisProvider;
    late MockUntisTimetable todayTimetable;
    late MockUntisTimetable futureTimetable;

    DateTime now = DateTime.now();

    setUp(() {
      mockUntisSession = MockUntisSession();
      todayTimetable = MockUntisTimetable();
      futureTimetable = MockUntisTimetable();
      untisProvider = UntisProvider(range: Duration(days: 30));

      when(mockUntisSession.getTimetable(
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
      )).thenAnswer((i) async => (i.namedArguments[const Symbol('startDate')] ==
              i.namedArguments[const Symbol('endDate')])
          ? todayTimetable
          : futureTimetable);
    });

    test('Initial values are correct', () {
      expect(untisProvider.untisSubjectsLoaded, isFalse);
      expect(untisProvider.todaySubjects, isEmpty);
      expect(untisProvider.untisSubjects, isEmpty);
      expect(untisProvider.untisSubjectStatus,
          equals(UntisSubjectStatus.untisUnavailable));
      expect(untisProvider.getNextLessonDates(), isEmpty);
      expect(untisProvider.getCurrentSubject(), isNull);
    });

    test('should filter today periods wich are canceled', () async {
      // setup
      int listenerCallsCounter = 0;
      final todayPeriods = <UntisPeriod>[
        createMockUntisPeriod(
          // valid
          subjectName: 'Math',
          isCancelled: false,
          withTeacher: true,
          start: now,
        ),
        createMockUntisPeriod(
          // canceled
          subjectName: 'History',
          isCancelled: true,
          withTeacher: true,
          start: now,
        ),
        createMockUntisPeriod(
          // wihtout teacher
          subjectName: 'Science',
          isCancelled: false,
          withTeacher: false,
          start: now,
        ),
        createMockUntisPeriod(
          // without subject
          isCancelled: false,
          withTeacher: true,
          start: now,
        ),
      ];
      when(todayTimetable.periods).thenReturn(todayPeriods);
      // verify
      untisProvider.addListener(() => listenerCallsCounter++);
      // test
      await untisProvider.updateCredentials(mockUntisSession);
      // wait for all async operations to complete
      await pumpEventQueue();
      // verify
      expect(listenerCallsCounter, equals(2));
      expect(untisProvider.untisSubjectsLoaded, isTrue);
      expect(
          untisProvider.untisSubjectStatus, equals(UntisSubjectStatus.loaded));

      expect(untisProvider.todaySubjects.length, equals(1));
      expect(untisProvider.todaySubjects.first.name, equals('Math'));

      expect(untisProvider.untisSubjects.length, equals(0));
    });

    test('should select the earliest next lesson wich is not cancelled',
        () async {
      int listenerCallsCounter = 0;
      final earlierValidTime = now.add(const Duration(days: 2));
      final cancelledTime = now.add(const Duration(days: 1));
      final latestTime = now.add(const Duration(days: 3));
      final futurePeriods = <UntisPeriod>[
        createMockUntisPeriod(
          // valid
          subjectName: 'Math',
          isCancelled: false,
          withTeacher: true,
          start: latestTime,
        ),
        createMockUntisPeriod(
          // earlier valid
          subjectName: 'Math',
          isCancelled: false,
          withTeacher: true,
          start: earlierValidTime,
        ),
        createMockUntisPeriod(
          // earlier but cancelled
          subjectName: 'Math',
          isCancelled: true,
          withTeacher: true,
          start: cancelledTime,
        ),
        createMockUntisPeriod(
          // different subject
          subjectName: 'Science',
          isCancelled: false,
          withTeacher: true,
          start: cancelledTime,
        ),
        createMockUntisPeriod(
          //earlier but without teacher
          subjectName: 'Math',
          isCancelled: false,
          withTeacher: false,
          start: cancelledTime,
        ),
      ];
      when(futureTimetable.periods).thenReturn(futurePeriods);
      // verify
      untisProvider.addListener(() => listenerCallsCounter++);
      // test
      await untisProvider.updateCredentials(mockUntisSession);
      // wait for all async operations to complete
      await pumpEventQueue();
      // verify
      expect(listenerCallsCounter, equals(2));
      expect(untisProvider.untisSubjectsLoaded, isTrue);
      expect(untisProvider.untisSubjectStatus, UntisSubjectStatus.loaded);

      expect(untisProvider.todaySubjects.length, equals(0));

      final nextLessons = untisProvider.getNextLessonDates();
      expect(nextLessons.length, equals(2));
      expect(nextLessons['untis_${'Math'.hashCode}'], earlierValidTime);
      expect(nextLessons['untis_${'Science'.hashCode}'], cancelledTime);
    });
  });
}
