import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/material.dart';

import '../../database/models/subject.dart';
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

  UntisDemoProvider({required Duration range}) : _range = range;

  @override
  DateTime get endDate => DateTime.now().add(_range);

  @override
  UntisSubjectStatus get untisSubjectStatus => .loaded;

  @override
  bool get untisSubjectsLoaded => true;

  @override
  bool get hasFreeTime => DateTime.now().hour >= 16;

  @override
  // TODO: implement teachers
  List<UntisTeacher> get teachers => throw UnimplementedError();

  @override
  List<Subject> get todaySubjects => DateTime.now().weekday <= 5
      ? _demoWeeklySchedule[DateTime.now().weekday]
      : [];

  @override
  List<Subject> get untisSubjects => _demoSubjects;

  @override
  Stream<TeacherSearchResult>? findTeacher(
    UntisElementDescriptor teacher, {
    bool searchInRoom = false,
    Set<UntisPeriod> previousResults = const {},
  }) {
    // TODO: implement findTeacher
    throw UnimplementedError();
  }

  @override
  UntisElementDescriptor? getCurrentSubject() {
    final subject = todaySubjects.firstWhereOrNull(
      (subject) => subject.id * 2 + 8 == DateTime.now().hour,
    );
    if (subject != null) {
      return UntisElementDescriptor(.subject, subject.id);
    }
    return null;
  }

  @override
  Map<String, DateTime> getNextLessonDates() {
    Map<String, DateTime> nextLessonDates = {};
    for (int day = 1; day <= 7; day++) {
      DateTime date = DateTime.now().add(Duration(days: day));
      if (date.weekday > 5) continue;
      for (int i = 0; i < _demoWeeklySchedule[date.weekday].length; i++) {
        Subject subject = _demoWeeklySchedule[date.weekday][i];
        nextLessonDates[subject.documentId] = date.add(
          Duration(hours: 2 * i + 8),
        );
      }
    }
    return nextLessonDates;
  }

  @override
  Duration? getTimeOfSubjectOnDay(DateTime date, Subject subject) {
    if (date.weekday > 5) return null;
    final subjectIndex = _demoWeeklySchedule[date.weekday].indexOf(subject);
    return subjectIndex != -1 ? Duration(hours: subjectIndex * 2 + 8) : null;
  }

  @override
  void loadUntisHomeworks() {}

  @override
  Future<void> updateCredentials(UntisSession? session) async {}
}
