import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService({required FirebaseAnalytics analytics})
      : _analytics = analytics;

  /// Logs the event of updating due dates.
  ///
  /// The parameter [count] indicates how many due dates were updated.
  Future<void> updateDueDates(int count) async {
    await _analytics
        .logEvent(name: 'update_due_dates', parameters: {'count': count});
  }

  /// Logs the event of creating a new homework.
  ///
  /// The parameter [isExam] indicates whether the homework is an exam.
  /// The parameter [isToNextLesson] indicates whether the due date is to be set to the next lesson.
  /// The parameter [isCreatedFast] indicates whether the homework was created using the fast create option.
  Future<void> createHomework(
      {required bool isExam,
      required bool isToNextLesson,
      required bool isCreatedFast}) async {
    await _analytics.logEvent(name: 'create_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      'method': isCreatedFast ? 'fast create' : 'normal'
    });
  }

  /// Logs the event of completing an homework.
  ///
  /// The parameter [isExam] indicates whether the homework is an exam.
  /// The Parameter [isPastDueBy] is optional and indicates by how much time the homework was past due when completed.
  Future<void> completeHomework(
      {required bool isExam, Duration? isPastDueBy}) async {
    await _analytics.logEvent(name: 'complete_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      if (isPastDueBy != null) 'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  /// Logs the event of completing an homework which is then deleted.
  ///
  /// The parameter [isExam] indicates whether the homework is an exam.
  /// The Parameter [isPastDueBy] is here required because a homework is delete if it is
  /// completed and past due, so this information is always available.
  Future<void> completeAndDeleteHomework(
      {required bool isExam, required Duration isPastDueBy}) async {
    await _analytics
        .logEvent(name: 'complete_and_delete_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  /// Logs the event of manually deleting an homework.
  ///
  /// The parameter [isExam] indicates whether the homework is an exam.
  /// The parameter [isCompleted] indicates whether the homework was completed before deletion.
  /// The parameter [isPastDueBy] is optional and indicates by how much time the homework was past due when deleted.
  Future<void> deleteHomework({
    required bool isExam,
    required bool isCompleted,
    Duration? isPastDueBy,
  }) async {
    await _analytics.logEvent(name: 'delete_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      'status': isCompleted ? 'completed' : 'not completed',
      if (isPastDueBy != null) 'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  /// Logs the event of reviving an homework.
  ///
  /// The parameter [isExam] indicates whether the homework is an exam.
  Future<void> reviveHomework({required bool isExam}) async {
    await _analytics.logEvent(
        name: 'revive_homework',
        parameters: {'type': isExam ? 'exam' : 'homework'});
  }
}
