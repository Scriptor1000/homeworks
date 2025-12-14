import 'package:firebase_analytics/firebase_analytics.dart';

import 'enums.dart';

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
  /// The parameter [type] indicates the type of the homework as [HomeworkType].
  /// The parameter [isToNextLesson] indicates whether the due date is to be set to the next lesson.
  /// The parameter [isCreatedFast] indicates whether the homework was created using the fast create option.
  Future<void> createHomework(
      {required HomeworkType type,
      required bool isToNextLesson,
      required bool isCreatedFast}) async {
    await _analytics.logEvent(name: 'create_homework', parameters: {
      'type': type.name,
      'method': isCreatedFast ? 'fast create' : 'normal'
    });
  }

  /// Logs the event of completing a homework.
  ///
  /// The parameter [type] indicates the type of the homework as [HomeworkType].
  /// The Parameter [isPastDueBy] is optional and indicates by how much time the homework was past due when completed.
  Future<void> completeHomework(
      {required HomeworkType type, Duration? isPastDueBy}) async {
    await _analytics.logEvent(name: 'complete_homework', parameters: {
      'type': type.name,
      if (isPastDueBy != null) 'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  /// Logs the event of uncompleting a homework.
  ///
  /// The parameter [type] indicates the type of the homework as [HomeworkType].
  /// The parameter [isDueIn] is optional and indicates in how much time the homework is due.
  void uncompleteHomework({required HomeworkType type, Duration? isDueIn}) {
    _analytics.logEvent(name: 'uncomplete_homework', parameters: {
      'type': type.name,
      if (isDueIn != null) 'isDueInMin': isDueIn.inMinutes,
    });
  }

  /// Logs the event of completing a homework which is then deleted.
  ///
  /// The parameter [type] indicates the type of the homework as [HomeworkType].
  /// The Parameter [isPastDueBy] is here required because a homework is deleted if it is
  /// completed and past due, so this information is always available.
  Future<void> completeAndDeleteHomework(
      {required HomeworkType type, required Duration isPastDueBy}) async {
    await _analytics
        .logEvent(name: 'complete_and_delete_homework', parameters: {
      'type': type.name,
      'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  /// Logs the event of manually deleting a homework.
  ///
  /// The parameter [type] indicates the type of the homework as [HomeworkType].
  /// The parameter [isCompleted] indicates whether the homework was completed before deletion.
  /// The parameter [isPastDueBy] is optional and indicates by how much time the homework was past due when deleted.
  Future<void> deleteHomework({
    required HomeworkType type,
    required bool isCompleted,
    Duration? isPastDueBy,
  }) async {
    await _analytics.logEvent(name: 'delete_homework', parameters: {
      'type': type.name,
      'status': isCompleted ? 'completed' : 'not completed',
      if (isPastDueBy != null) 'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  /// Logs the event of reviving a homework.
  ///
  /// The parameter [type] indicates the type of the homework as [HomeworkType].
  Future<void> reviveHomework({required HomeworkType type}) async {
    await _analytics
        .logEvent(name: 'revive_homework', parameters: {'type': type.name});
  }
}
