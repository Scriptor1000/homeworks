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

/// Provider for managing homeworks
///
/// This class handles loading, creating, updating, and deleting homeworks.
/// It interacts with [FirestoreHomeworks] for persistent storage and keeps
/// a local list [_homeworks] in sync.
class HomeworksProvider extends ChangeNotifier {
  List<Homework> _homeworks = []; // local list of homeworks
  bool _homeworksLoaded = false; // whether homeworks have been loaded

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

  /// Loads all homeworks from Firestore and removes old completed ones
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
      await _firestoreHomeworks.deleteHomework(homework.documentId);
    }

    // Remove the same homeworks locally
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

  Homework? getById(String id) {
    return _homeworks.firstWhereOrNull(
      (hw) => hw.documentId == id || hw.id == id,
    );
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
      emoji: null,
    );
    return _mutateState(
      mutateLocalState: () => _homeworks.add(homework),
      mutateRemoteState: () async =>
          await _firestoreHomeworks.saveHomework(homework),
      logAnalytics: () => _analyticsService.createHomework(
        type: homework.type,
        isToNextLesson: homework.toNextLesson,
        isCreatedFast: true,
      ),
    );
  }

  /// Creates a homework from a full [Homework] object
  ///
  /// Adds it to the local list and saves in Firestore.
  Future<void> createHomework(Homework homework) async {
    return _mutateState(
      mutateLocalState: () => _homeworks.add(homework),
      mutateRemoteState: () async =>
          await _firestoreHomeworks.saveHomework(homework),
      logAnalytics: () => _analyticsService.createHomework(
        type: homework.type,
        isToNextLesson: homework.toNextLesson,
        isCreatedFast: false,
      ),
    );
  }

  Future<void> updateHomework(Homework updatedHomework) async {
    final homework = _homeworks.firstWhereOrNull(
      (hw) =>
          hw.documentId == updatedHomework.documentId ||
          hw.id == updatedHomework.id,
    );
    if (homework == null) {
      Sentry.logger.error(
        'Homework with id ${updatedHomework.id} not found for updating. '
        'Current homeworks ID: ${_homeworks.map((hw) => hw.id).join(', ')}',
      );
      return;
    }
    return _mutateState(
      mutateLocalState: () {
        homework.title = updatedHomework.title;
        homework.description = updatedHomework.description;
        homework.subjectDocId = updatedHomework.subjectDocId;
        homework.toNextLesson = updatedHomework.toNextLesson;
        homework.dueDate = updatedHomework.dueDate;
        homework.type = updatedHomework.type;
        homework.emoji = updatedHomework.emoji;
      },
      mutateRemoteState: () async =>
          await _firestoreHomeworks.saveHomework(homework),
      logAnalytics: () {},
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
      return _mutateState(
        mutateLocalState: () => _homeworks.remove(homework),
        mutateRemoteState: () async =>
            await _firestoreHomeworks.deleteHomework(homework.documentId),
        logAnalytics: () => _analyticsService.deleteHomework(
          type: homework.type,
          isPastDueBy: homework.dueDate != null
              ? DateTime.now().difference(homework.dueDate!)
              : null,
          isCompleted: homework.isCompleted,
        ),
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
      return _mutateState(
        mutateLocalState: () => homework.dueDate = dueDate,
        mutateRemoteState: () async =>
            await _firestoreHomeworks.saveHomework(homework),
        logAnalytics: () =>
            _analyticsService.reviveHomework(type: homework.type),
      );
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
      return _mutateState(
        mutateLocalState: () => _homeworks.remove(homework),
        mutateRemoteState: () async =>
            await _firestoreHomeworks.deleteHomework(homework.documentId),
        logAnalytics: () => _analyticsService.completeAndDeleteHomework(
          type: homework.type,
          isPastDueBy: DateTime.now().difference(homework.dueDate!),
        ),
      );
    } else {
      return _mutateState(
        mutateLocalState: () => homework.isCompleted = true,
        mutateRemoteState: () async =>
            await _firestoreHomeworks.saveHomework(homework),
        logAnalytics: () => _analyticsService.completeHomework(
          type: homework.type,
          isPastDueBy: homework.dueDate != null
              ? DateTime.now().difference(homework.dueDate!)
              : null,
        ),
      );
    }
  }

  Future<void> _uncompleteHomework(Homework homework) async {
    return _mutateState(
      mutateLocalState: () => homework.isCompleted = false,
      mutateRemoteState: () async =>
          await _firestoreHomeworks.saveHomework(homework),
      logAnalytics: () => _analyticsService.uncompleteHomework(
        type: homework.type,
        isDueIn: homework.dueDate?.difference(DateTime.now()),
      ),
    );
  }

  Future<void> _mutateState({
    required VoidCallback mutateLocalState,
    required Future<void> Function() mutateRemoteState,
    required VoidCallback logAnalytics,
  }) async {
    mutateLocalState();
    await mutateRemoteState();
    notifyListeners();
    logAnalytics();
  }
}
