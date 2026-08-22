import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/foundation.dart';

import '../database/models/lesson.dart';
import '../utilities/enums.dart';
import 'credential_provider.dart';

/// Provider for the user's weekly timetable.
///
/// Fetches periods for a given week from the Untis API via the session
/// exposed by [CredentialProvider], and converts them into [TimetableLesson]s
/// for display in `TimetableWidget`.
///
/// This re-uses [UntisSubjectStatus] to describe the timetable's status,
/// since its values (untisUnavailable / loading / error / loaded) describe
/// this data just as well. Feel free to introduce a dedicated status enum
/// in `enums.dart` if you'd prefer a more specific name.
class TimetableProvider extends ChangeNotifier {
  List<TimetableLesson> _lessons = [];
  UntisSubjectStatus _status = UntisSubjectStatus.untisUnavailable;
  DateTime? _loadedWeekStart;

  /// The lessons for [loadedWeekStart], if any.
  List<TimetableLesson> get lessons => _lessons;

  /// The current status of the timetable data.
  UntisSubjectStatus get status => _status;

  /// The Monday of the week [lessons] currently covers, or `null` if no
  /// week has been loaded yet.
  DateTime? get loadedWeekStart => _loadedWeekStart;

  /// Fetches the timetable for the week starting at [weekStart] (a Monday)
  /// using [credentialProvider]'s current Untis session.
  ///
  /// Does nothing if there is no usable session, or if [weekStart] is
  /// already loaded.
  Future<void> updateFromSession(
    CredentialProvider credentialProvider,
    DateTime weekStart,
  ) async {
    final session = credentialProvider.session;

    if (credentialProvider.sessionStatus !=
            UntisSessionStatus.sessionAccomplished ||
        session == null) {
      if (_status != UntisSubjectStatus.untisUnavailable) {
        _lessons = [];
        _status = UntisSubjectStatus.untisUnavailable;
        _loadedWeekStart = null;
        notifyListeners();
      }
      return;
    }

    if (_loadedWeekStart == weekStart && _status == UntisSubjectStatus.loaded) {
      return;
    }

    _status = UntisSubjectStatus.loading;
    notifyListeners();

    try {
      final timetable = await session.getTimetable(
        startDate: weekStart,
        endDate: weekStart.add(const Duration(days: 6)),
      );

      _lessons = timetable.periods
          .map(_lessonFromPeriod)
          .whereType<TimetableLesson>()
          .toList();
      _status = UntisSubjectStatus.loaded;
      _loadedWeekStart = weekStart;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error loading timetable: $error');
      }
      _lessons = [];
      _status = UntisSubjectStatus.error;
      _loadedWeekStart = null;
    }

    notifyListeners();
  }

  /// Maps a single [UntisPeriod] to a [TimetableLesson], or `null` if the
  /// period has no subject and therefore can't be displayed meaningfully.
  TimetableLesson? _lessonFromPeriod(UntisPeriod period) {
    final subject = period.subject;
    if (subject == null) return null;
    return TimetableLesson(
      subjectShortName: subject.name,
      subjectName: subject.longName,
      room: period.room?.name ?? '',
      teacher: period.teacher?.fullName,
      start: period.startDateTime,
      end: period.endDateTime,
      state: LessonState.regular,
    );
  }
}
