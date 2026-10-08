import 'package:flutter/widgets.dart';

import '../database/models/homework.dart';
import '../utilities/analytics_service.dart';
import 'homeworks_provider.dart';
import 'subject_provider.dart';
import 'untis_provider.dart';

class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  HomeworksProvider _homeworksProvider;
  UntisProvider _untisProvider;
  SubjectProvider _subjectProvider;

  final AnalyticsService _analyticsService;

  new({
    required this._homeworksProvider,
    required this._untisProvider,
    required this._subjectProvider,
    required this._analyticsService,
  });

  void providerUpdate({
    required HomeworksProvider homeworksProvider,
    required UntisProvider untisProvider,
    required SubjectProvider subjectProvider,
  }) {
    _homeworksProvider = homeworksProvider;
    _untisProvider = untisProvider;
    _subjectProvider = subjectProvider;
    _isSyncing = true;
    notifyListeners();
    _deleteOldCompletedHomeworks();
    _updateDueDates();
    _isSyncing = false;
    notifyListeners();
  }

  Future<void> _deleteOldCompletedHomeworks() async {
    final now = DateTime.now();
    final toDelete = _homeworksProvider.homeworks
        .where(
          (homework) =>
              homework.dueDate != null &&
              homework.dueDate!.isBefore(now) &&
              homework.isCompleted,
        )
        .toList();
    for (var homework in toDelete) {
      await _homeworksProvider.deleteHomework(homework.documentId);
    }
    notifyListeners();
  }

  Future<void> _updateDueDates() async {
    if (!_untisProvider.untisSubjectsLoaded) {
      return;
    }
    final nextLessonDates = _untisProvider.getNextLessonDates();
    final todaySubjects = _untisProvider.todaySubjects;
    final now = DateTime.now();
    int count = 0;

    bool isPastDue(DateTime? dueDate) =>
        dueDate != null && dueDate.isBefore(now);
    bool happensToday(Homework homework) =>
        todaySubjects.any((s) => s.documentId == homework.subjectDocId);

    for (var homework in _homeworksProvider.homeworks) {
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
          homework.dueDate!.isBefore(_untisProvider.endDate)) {
        homework.dueDate = null;
        _homeworksProvider.updateHomework(homework);
        count++;
      } else
      // If there is a next lesson date which differs from the due date
      if (nextLessonDates.containsKey(homework.subjectDocId) &&
          nextLessonDates[homework.subjectDocId] != homework.dueDate) {
        homework.dueDate = nextLessonDates[homework.subjectDocId];
        _homeworksProvider.updateHomework(homework);
        count++;
      }
    }
    notifyListeners();

    _analyticsService.updateDueDates(count);
  }

  void updateNextLessons() {
    if (!_untisProvider.untisSubjectsLoaded) {
      return;
    }
    final nextLessonDates = _untisProvider.getNextLessonDates();
    for (var entry in nextLessonDates.entries) {
      _subjectProvider.updateNextLessonForSubject(entry.key, entry.value);
    }
  }

  void updateUntisSubjects() {
    if (!_untisProvider.untisSubjectsLoaded) {
      return;
    }
    _subjectProvider.setUntisSubjects(
      _untisProvider.untisSubjects,
      _untisProvider.untisSubjectStatus,
    );
  }
}
