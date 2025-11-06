import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService({required FirebaseAnalytics analytics})
      : _analytics = analytics;

  Future<void> updateDueDates(int count) async {
    await _analytics
        .logEvent(name: 'update_due_dates', parameters: {'count': count});
  }

  Future<void> createHomework(
      {required bool isExam,
      required bool isToNextLesson,
      required bool isCreatedFast}) async {
    await _analytics.logEvent(name: 'create_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      'method': isCreatedFast ? 'fast create' : 'normal'
    });
  }

  Future<void> completeHomework(
      {required bool isExam, Duration? isPastDueBy}) async {
    await _analytics.logEvent(name: 'complete_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      if (isPastDueBy != null) 'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

  Future<void> completeAndDeleteHomework(
      {required bool isExam, required Duration isPastDueBy}) async {
    await _analytics
        .logEvent(name: 'complete_and_delete_homework', parameters: {
      'type': isExam ? 'exam' : 'homework',
      'isPastDueByMin': isPastDueBy.inMinutes,
    });
  }

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

  Future<void> reviveHomework({required bool isExam}) async {
    await _analytics.logEvent(
        name: 'revive_homework',
        parameters: {'type': isExam ? 'exam' : 'homework'});
  }
}
