import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/material.dart';

import '../../database/models/subject.dart';
import '../../utilities/common.dart';
import '../../utilities/enums.dart';
import '../untis_provider.dart';

Subject _exampleSubject(int id, Color backColor) {
  return Subject(
    id: id,
    name: 'Demo Subject $id',
    shortName: 'D$id',
    backColor: backColor,
    foreColor: backColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    fromUntis: true,
    nextLesson: normalizeDate(DateTime.now())
        .add(Duration(days: id + 1))
        .add(_getTimeOfDayForIndex(id % 5)),
  );
}

List<Subject> _demoSubjects = [
  _exampleSubject(0, Colors.grey),
  _exampleSubject(1, Colors.red),
  _exampleSubject(2, Colors.green),
  _exampleSubject(3, Colors.blue),
  _exampleSubject(4, Colors.orange),
  _exampleSubject(5, Colors.purple),
  _exampleSubject(6, Colors.teal),
  _exampleSubject(7, Colors.yellow),
  _exampleSubject(8, Colors.cyan),
  _exampleSubject(9, Colors.pink),
];

List<List<Subject>> _demoWeeklySchedule = List.generate(7, (day) {
  return List.generate(5, (lesson) {
    int subjectIndex = (day * 3 + lesson) % _demoSubjects.length;
    return _demoSubjects[subjectIndex];
  });
});

class UntisDemoProvider extends ChangeNotifier implements UntisProvider {
  @override
  Future<DateTime?> deepNextLessonSearch(
    Subject subject,
    StreamController<DateTime> stream,
    Completer<void> abort,
  ) {
    throw UnimplementedError();
  }

  final Duration _range;

  UntisDemoProvider({required this._range});

  @override
  DateTime get endDate => DateTime.now().add(_range);

  @override
  UntisSubjectStatus get untisSubjectStatus => .loaded;

  @override
  bool get untisSubjectsLoaded => true;

  @override
  bool get hasFreeTime => DateTime.now().hour >= 16;

  @override
  List<OwnUntisTeacher> get teachers => .generate(
    5,
    (i) => OwnUntisTeacher(
      id: UntisElementDescriptor(.teacher, i),
      fullName: 'Demo Teacher $i',
    ),
  );

  @override
  List<Subject> get todaySubjects =>
      _demoWeeklySchedule[DateTime.now().weekday - 1];

  @override
  List<Subject> get untisSubjects => _demoSubjects;

  @override
  Stream<TeacherSearchResult>? findTeacher(
    UntisElementDescriptor teacher, {
    bool searchInRoom = false,
    Set<FoundPeriod> previousResults = const {},
  }) async* {
    if (teacher.type != .teacher) {
      throw ArgumentError('Expected a teacher descriptor');
    }

    List<FoundPeriod> results = [];

    for (int day = 0; day < 7; day++) {
      yield TeacherSearchResult(
        periods: results.toSet(),
        currentSearchingPlace: '$day',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      for (int i = 0; i < _demoWeeklySchedule[day].length; i++) {
        DateTime startTime = normalizeDate(DateTime.now())
            .add(Duration(days: day))
            .add(_getTimeOfDayForIndex(i));
        final period = FoundPeriod(
          startDateTime: startTime,
          endDateTime: startTime.add(const Duration(hours: 1)),
          roomNames: ['R00${i + 1}'],
          classNames: ['B${(i + 1) % 3 + 6}'],
          isCancelled: i % 3 == 0,
          id: day * 10 + i,
        );
        results.add(period);
      }
    }
    yield TeacherSearchResult(periods: results.toSet());
  }

  @override
  UntisElementDescriptor? getCurrentSubject() {
    final subject = todaySubjects.firstWhereIndexedOrNull(
      ((index, _) =>
          _getTimeOfDayForIndex(index).inHours == DateTime.now().hour),
    );
    if (subject != null) {
      return UntisElementDescriptor(.subject, subject.id);
    }
    return null;
  }

  @override
  Map<String, DateTime> getNextLessonDates() => Map.fromEntries(
    _demoSubjects
        .where((subject) => subject.nextLesson != null)
        .map((subject) => MapEntry(subject.documentId, subject.nextLesson!)),
  );

  @override
  Duration? getTimeOfSubjectOnDay(DateTime date, Subject subject) {
    int index = _demoWeeklySchedule[date.weekday - 1].indexWhere(
      (s) => s.documentId == subject.documentId,
    );
    return index == -1 ? null : _getTimeOfDayForIndex(index);
  }

  @override
  void loadUntisHomeworks() {}

  @override
  Future<void> updateCredentials(UntisSession? session) async {}
}

Duration _getTimeOfDayForIndex(int index) {
  return Duration(hours: index * 2 + 8, minutes: 0);
}
