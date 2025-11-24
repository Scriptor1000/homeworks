import 'package:flutter/material.dart';

import '../database/homeworks.dart';
import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../utilities/analytics_service.dart';
import '../utilities/homeworks_list.dart';
import '../utilities/constants.dart';
import 'untis_provider.dart';

class HomeworksProvider extends ChangeNotifier {
  List<Homework> _homeworks = [];
  bool _homeworksLoaded = false;

  final FirestoreHomeworks _firestoreHomeworks;
  final AnalyticsService _analyticsService;

  HomeworksProvider(
      {required FirestoreHomeworks firestoreHomeworks,
      required AnalyticsService analyticsService})
      : _firestoreHomeworks = firestoreHomeworks,
        _analyticsService = analyticsService;

  /// The list of homeworks which have a due date.
  ///
  /// This list is unmodifiable because any change should be done through the methods of this provider.
  Homeworks get homeworks =>
      Homeworks(homeworks: List.unmodifiable(_homeworks));

  /// Wheter the homeworks are loaded from Firestore.
  bool get homeworksLoaded => _homeworksLoaded;

  /// Initializes the provider by loading subjects and homeworks from Firestore.
  ///
  /// This method should be called at the start of the application to ensure data is loaded or
  /// to refresh the data.
  Future<void> initialize() async {
    await _loadHomeworks();
    notifyListeners();
  }

  Future<void> _loadHomeworks() async {
    _homeworks = await _firestoreHomeworks.loadAllHomeworks();
    final now = DateTime.now();
    // TODO there is a better place for deleting old homeworks
    final toDelete = _homeworks
        .where((homework) =>
            homework.dueDate != null &&
            homework.dueDate!.isBefore(now) &&
            homework.isCompleted)
        .toList();
    for (var homework in toDelete) {
      await _firestoreHomeworks.deleteHomework(homework.id);
    }
    _homeworks.removeWhere((homework) =>
        homework.dueDate != null &&
        homework.dueDate!.isBefore(now) &&
        homework.isCompleted);
    _homeworksLoaded = true;
    notifyListeners();
  }

  Future<void> updateDueDates(UntisProvider untisProvider) async {
    if (!untisProvider.untisSubjectsLoaded) {
      return;
    }
    final nextLessonDates = untisProvider.getNextLessonDates();
    final todaySubjects = untisProvider.todaySubjects;
    final now = DateTime.now();
    int count = 0;

    bool isPastDue(DateTime? dueDate) =>
        dueDate != null && dueDate.isBefore(now);
    bool happensToday(Homework homework) =>
        todaySubjects.any((s) => s.documentId == homework.subjectDocId);

    for (var homework in _homeworks) {
      // Check if homework is addressed
      if (!homework.toNextLesson ||
          homework.fromUntis ||
          isPastDue(homework.dueDate) ||
          happensToday(homework)) {
        continue;
      }

      // If there is no next lesson date and
      // the due date is in the scan range
      if (!nextLessonDates.containsKey(homework.subjectDocId) &&
          homework.dueDate != null &&
          homework.dueDate!.isBefore(untisProvider.endDate)) {
        homework.dueDate = null;
        _firestoreHomeworks.saveHomework(homework);
        count++;
      } else
      // If there is a next lesson date which differs from the due date
      if (nextLessonDates.containsKey(homework.subjectDocId) &&
          nextLessonDates[homework.subjectDocId] != homework.dueDate) {
        homework.dueDate = nextLessonDates[homework.subjectDocId];
        _firestoreHomeworks.saveHomework(homework);
        count++;
      }
    }
    notifyListeners();

    _analyticsService.updateDueDates(count);
  }

  /// Creates a new homework and stores it in Firestore and updates the local list.
  ///
  /// It generates a new [Homework] object with the given [title] and [subject], the rest is filled with standard values.
  /// If the title starts with any of the [examPrefixes], it will be marked as an exam.
  /// The homework will be added to the [_homeworks] list and saved in Firestore.
  Future<void> fastCreateHomework(String title, Subject subject) async {
    final nextLesson = subject.nextLesson;
    bool isExam = false;
    for (final prefix in examPrefixes) {
      if (title.startsWith(prefix)) {
        isExam = true;
        title = title.replaceFirst(prefix, '').trim();
        break;
      }
    }
    var homework = Homework(
      title: title,
      description: '',
      subjectDocId: subject.documentId,
      toNextLesson: true,
      isCompleted: false,
      dueDate: nextLesson,
      fromUntis: false,
      isExam: isExam,
    );
    _homeworks.add(homework);
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();

    _analyticsService.createHomework(
        isExam: isExam, isToNextLesson: true, isCreatedFast: true);
  }

  Future<void> createHomework(Homework homework) async {
    _homeworks.add(homework);
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();

    _analyticsService.createHomework(
        isExam: homework.isExam,
        isToNextLesson: homework.toNextLesson,
        isCreatedFast: false);
  }

  /// Deletes a homework from Firestore and [_homeworks].
  ///
  /// It finds the homework by the `Id` Attribut of [Homework] in the [_homeworks] list and removes it.
  /// The homework is also deleted from Firestore.
  Future<void> deleteHomework(Homework homework) async {
    final index = _homeworks.indexWhere((hw) => hw.id == homework.id);
    if (index != -1) {
      await _firestoreHomeworks.deleteHomework(homework.documentId);
      _homeworks.removeAt(index);
      notifyListeners();

      _analyticsService.deleteHomework(
          isExam: homework.isExam,
          isPastDueBy: homework.dueDate != null
              ? DateTime.now().difference(homework.dueDate!)
              : null,
          isCompleted: homework.isCompleted);
    } else {
      print('Homework with id ${homework.id} not found.');
      print('Current homeworks: ${_homeworks.map((hw) => hw.id).join(', ')}');
    }
  }

  /// Updates an existing homework in Firestore and [_homeworks].
  ///
  /// It finds the homework by the `Id` Attribut of [Homework] in the [_homeworks] list and updates its due date.
  /// The updated homework is also saved in Firestore.
  Future<void> newDueDate(Homework homework, DateTime dueDate) async {
    final index = _homeworks.indexWhere((hw) => hw.id == homework.id);
    if (index != -1) {
      _homeworks[index].dueDate = dueDate;
      await _firestoreHomeworks.saveHomework(_homeworks[index]);
      notifyListeners();

      // because this functions is only called when a homework is revived
      _analyticsService.reviveHomework(isExam: homework.isExam);
    } else {
      print('Homework with id ${homework.id} not found.');
      print('Current homeworks: ${_homeworks.map((hw) => hw.id).join(', ')}');
    }
  }

  Future<void> completeHomework(Homework homework) async {
    final index = _homeworks.indexWhere((hw) => hw.id == homework.id);
    if (index != -1) {
      if (_homeworks[index].dueDate != null &&
          _homeworks[index].dueDate!.isBefore(DateTime.now())) {
        _homeworks.removeAt(index);
        await _firestoreHomeworks.deleteHomework(homework.documentId);
        notifyListeners();

        _analyticsService.completeAndDeleteHomework(
            isExam: homework.isExam,
            isPastDueBy: DateTime.now().difference(homework.dueDate!));
      } else {
        _homeworks[index].isCompleted = true;
        await _firestoreHomeworks.saveHomework(_homeworks[index]);
        notifyListeners();

        _analyticsService.completeHomework(
            isExam: homework.isExam,
            isPastDueBy: homework.dueDate != null
                ? DateTime.now().difference(homework.dueDate!)
                : null);
      }
    } else {
      print('Homework with id ${homework.id} not found.');
      print('Current homeworks: ${_homeworks.map((hw) => hw.id).join(', ')}');
    }
  }
}
