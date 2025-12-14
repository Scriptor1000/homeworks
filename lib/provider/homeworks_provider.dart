import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../database/homeworks.dart';
import '../database/models/homework.dart';
import '../database/models/subject.dart';
import '../utilities/analytics_service.dart';
import '../utilities/enums.dart';
import '../utilities/homeworks_list.dart';
import '../utilities/constants.dart';
import 'untis_provider.dart';

class HomeworksProvider extends ChangeNotifier {
  List<Homework> _homeworks = [];
  bool _homeworksLoaded = false;

  final FirestoreHomeworks _firestoreHomeworks;
  final AnalyticsService _analyticsService;

  HomeworksProvider({
    required FirestoreHomeworks firestoreHomeworks,
    required AnalyticsService analyticsService,
  }) : _firestoreHomeworks = firestoreHomeworks,
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
        .where(
          (homework) =>
              homework.dueDate != null &&
              homework.dueDate!.isBefore(now) &&
              homework.isCompleted,
        )
        .toList();
    for (var homework in toDelete) {
      await _firestoreHomeworks.deleteHomework(homework.id);
    }
    _homeworks.removeWhere(
      (homework) =>
          homework.dueDate != null &&
          homework.dueDate!.isBefore(now) &&
          homework.isCompleted,
    );
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
    HomeworkType type = HomeworkType.homework;
    for (final prefix in examPrefixes) {
      if (title.startsWith(prefix)) {
        type = HomeworkType.exam;
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
      type: type,
    );
    _homeworks.add(homework);
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();

    _analyticsService.createHomework(
      type: type,
      isToNextLesson: true,
      isCreatedFast: true,
    );
  }

  Future<void> createHomework(Homework homework) async {
    _homeworks.add(homework);
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();

    _analyticsService.createHomework(
      type: homework.type,
      isToNextLesson: homework.toNextLesson,
      isCreatedFast: false,
    );
  }

  /// Deletes a homework from Firestore and [_homeworks].
  ///
  /// It finds the homework by its [HomeworkID] in the [_homeworks] list and removes it.
  /// The homework is also deleted from Firestore. If no homework with the given ID is found,
  /// an error is logged to Sentry but no exception is raised.
  Future<void> deleteHomework(String homeworkID) async {
    final homework = _homeworks.firstWhereOrNull((hw) => hw.id == homeworkID);
    if (homework != null) {
      await _firestoreHomeworks.deleteHomework(homework.documentId);
      _homeworks.remove(homework);
      notifyListeners();

      _analyticsService.deleteHomework(
        type: homework.type,
        isPastDueBy: homework.dueDate != null
            ? DateTime.now().difference(homework.dueDate!)
            : null,
        isCompleted: homework.isCompleted,
      );
    } else {
      Sentry.logger.error(
        'Homework with id $homeworkID not found for deleting. '
        'Current homeworks ID: ${_homeworks.map((hw) => hw.id).join(', ')}',
      );
    }
  }

  /// Updates an existing homework in Firestore and [_homeworks].
  ///
  /// It finds the homework by its [HomeworkID] in the [_homeworks] list and updates its due date.
  /// The updated homework is also saved in Firestore. If no homework with the given ID is found,
  /// an error is logged to Sentry but no exception is raised.
  Future<void> newDueDate(String homeworkID, DateTime dueDate) async {
    final homework = _homeworks.firstWhereOrNull((hw) => hw.id == homeworkID);
    if (homework != null) {
      homework.dueDate = dueDate;
      await _firestoreHomeworks.saveHomework(homework);
      notifyListeners();

      // because this functions is only called when a homework is revived
      _analyticsService.reviveHomework(type: homework.type);
    } else {
      Sentry.logger.error(
        'Homework with id $homeworkID not found for new due date. '
        'Current homeworks ID: ${_homeworks.map((hw) => hw.id).join(', ')}',
      );
    }
  }

  /// Changes the completion status of a homework in Firestore and [_homeworks].
  ///
  /// It finds the homework by its [HomeworkID] in the [_homeworks] list and toggles its isCompleted flag.
  /// The updated homework is also saved in Firestore. If no homework with the given ID is found,
  /// an error is logged to Sentry but no exception is raised.
  Future<void> toggleHomeworkCompletion(String homeworkID) {
    final homework = _homeworks.firstWhereOrNull((hw) => hw.id == homeworkID);
    if (homework != null) {
      if (homework.isCompleted) {
        return _uncompleteHomework(homework);
      } else {
        return _completeHomework(homework);
      }
    } else {
      Sentry.logger.error(
        'Homework with id $homeworkID not found for changing status. '
        'Current homeworks ID: ${_homeworks.map((hw) => hw.id).join(', ')}',
      );
      return Future.value();
    }
  }

  Future<void> _completeHomework(Homework homework) async {
    if (homework.dueDate != null &&
        homework.dueDate!.isBefore(DateTime.now())) {
      _homeworks.remove(homework);
      await _firestoreHomeworks.deleteHomework(homework.documentId);
      notifyListeners();

      _analyticsService.completeAndDeleteHomework(
        type: homework.type,
        isPastDueBy: DateTime.now().difference(homework.dueDate!),
      );
    } else {
      homework.isCompleted = true;
      await _firestoreHomeworks.saveHomework(homework);
      notifyListeners();

      _analyticsService.completeHomework(
        type: homework.type,
        isPastDueBy: homework.dueDate != null
            ? DateTime.now().difference(homework.dueDate!)
            : null,
      );
    }
  }

  Future<void> _uncompleteHomework(Homework homework) async {
    homework.isCompleted = false;
    await _firestoreHomeworks.saveHomework(homework);
    notifyListeners();

    _analyticsService.uncompleteHomework(
      type: homework.type,
      isDueIn: homework.dueDate?.difference(DateTime.now()),
    );
  }
}
