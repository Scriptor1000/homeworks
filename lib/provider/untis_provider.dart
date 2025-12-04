import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../database/models/credentials.dart';
import '../utilities/enums.dart';
import '../database/models/subject.dart';

/// Provider for managing Untis data
///
/// This class handles the loading and updating of Untis subjects and timetable.

class UntisProvider extends ChangeNotifier {
  UntisSession? _session;

  List<UntisPeriod> _todayPeriods = [];
  List<Subject> _untisSubjects = [];
  List<UntisTeacher> _untisTeachers = [];
  UntisSubjectStatus _untisSubjectStatus = UntisSubjectStatus.untisUnavailable;

  final Duration _range;

  UntisProvider({required Duration range}) : _range = range;

  /// The List of Subjects from Untis in the next 30 days.
  List<Subject> get untisSubjects => _untisSubjects;

  List<UntisTeacher> get teachers => _untisTeachers;

  /// The date until the timetable is loaded.
  DateTime get endDate => DateTime.now().add(_range);

  /// Only the next Lesson Dates
  Map<String, DateTime> getNextLessonDates() => Map.fromEntries(
    _untisSubjects
        .where((subject) => subject.nextLesson != null)
        .map((subject) => MapEntry(subject.documentId, subject.nextLesson!)),
  );

  /// The current status of the Untis subjects.
  ///
  /// This can be:
  /// - [UntisSubjectStatus.untisUnavailable]: [UntisCredentials] is not available.
  /// - [UntisSubjectStatus.loading]: Untis subjects are currently being loaded.
  /// - [UntisSubjectStatus.loaded]: Untis subjects are loaded and available.
  /// - [UntisSubjectStatus.error]: An error occurred while loading Untis subjects.
  UntisSubjectStatus get untisSubjectStatus => _untisSubjectStatus;

  /// All subjects which happen today.
  List<Subject> get todaySubjects => _todayPeriods
      .where(
        (period) =>
            !period.isCancelled &&
            period.subject != null &&
            period.teacher != null,
      )
      .map((period) => Subject.fromUntisSubject(period.subject!))
      .toList();

  /// Whether the Untis subjects are loaded and available.
  bool get untisSubjectsLoaded =>
      _untisSubjectStatus == UntisSubjectStatus.loaded;

  /// Checks the [_todayPeriods] and returns the current subject based on the current time.
  ///
  /// The current subject is determined as the last period which started before now and ended in the last 30 minutes.
  /// This uses [lastWhereOrNull] to ensure that if multiple periods match, the most recent one (closest to now) is selected,
  /// which is important for single periods without a pause between.
  Subject? getCurrentSubject() {
    final now = DateTime.now();
    final currentPeriod = _todayPeriods.lastWhereOrNull(
      (period) =>
          !period.isCancelled &&
          period.teacher != null &&
          period.subject != null &&
          period.startDateTime.isBefore(now) &&
          period.endDateTime.isAfter(now.subtract(const Duration(minutes: 30))),
    );
    if (currentPeriod == null) {
      return null;
    }
    Subject currentSubject = Subject.fromUntisSubject(currentPeriod.subject!);
    final nextLessonDates = getNextLessonDates();
    if (nextLessonDates.containsKey(currentSubject.documentId)) {
      currentSubject.nextLesson = nextLessonDates[currentSubject.documentId];
    }
    return currentSubject;
  }

  /// Updates the Untis credentials and loads the timetable if the credentials has changed.
  ///
  /// This method should be called from the update Method of [ProxyProvider].
  Future<void> updateCredentials(UntisSession? session) async {
    if (session == _session) {
      return;
    }
    if (session == null) {
      _untisSubjects = [];
      _untisSubjectStatus = UntisSubjectStatus.untisUnavailable;
      notifyListeners();
      return;
    }
    _session = session;
    _getTimetable();
  }

  Future<void> _getTimetable() async {
    if (_session == null) return;

    _untisSubjectStatus = UntisSubjectStatus.loading;
    notifyListeners();

    try {
      // You have to edit the Package, the check if the difference is
      // negative is vice versa (start and end date are swapped)
      DateTime startDate = DateTime.now();
      DateTime endDate = startDate.add(_range);

      // Load user date to ensure teachers are available
      await _session!.getUserData();
      _untisTeachers = (await _session!.teachers)
          .where((t) => t.exitDate == null)
          .toList();

      // the periods today are loaded extra to find the current subject simpler
      _todayPeriods = await _session!
          .getTimetable(startDate: startDate, endDate: startDate)
          .then((timetable) => timetable.periods);

      final timetable = await _session!.getTimetable(
        startDate: startDate,
        endDate: endDate,
      );

      for (var period in timetable.periods) {
        _parsePeriod(period);
      }

      _untisSubjectStatus = UntisSubjectStatus.loaded;
    } catch (error, stackTrace) {
      _untisSubjectStatus = UntisSubjectStatus.error;
      print('Error loading timetable: $error');
      Sentry.captureException(error, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }

  void _parsePeriod(UntisPeriod period) {
    DateTime now = DateTime.now();
    DateTime todayNight = DateTime(now.year, now.month, now.day + 1);
    if (period.subject == null) {
      return;
    }
    // sometimes only teacher is removed but the period is not cancelled
    final isCancelled = period.isCancelled || period.teacher == null;

    // this is the subject from the list, if the subject is already in the list
    final listedSubject = _untisSubjects.firstWhereOrNull(
      (s) => s.id == period.subject!.id.id,
    );

    // if not, it is added with a next lesson date (if it is not cancelled and after today)
    if (listedSubject == null) {
      final subject = Subject.fromUntisSubject(period.subject!);

      if (!isCancelled && period.startDateTime.isAfter(todayNight)) {
        subject.nextLesson = period.startDateTime;
      }
      _untisSubjects.add(subject);

      // if a not cancelled period is before the next lesson (which shouldn't be the case because
      // the periods should be ordered) or there isn't a next lesson (which could be because the
      // first lesson in which the subject was found was cancelled) then the next lesson is updated
    } else if (!isCancelled &&
        (listedSubject.nextLesson == null ||
            period.startDateTime.isBefore(listedSubject.nextLesson!)) &&
        period.startDateTime.isAfter(todayNight)) {
      // NOTE: you can make the change  on the variable because it is only a reference to
      // the subject in the list, so this changes the subject in the list
      listedSubject.nextLesson = period.startDateTime;
    }
  }

  /// Finds the timetable periods for a given teacher.
  ///
  /// This method searches for periods associated with the specified [teacher] across all classes or rooms,
  /// depending on the [searchInRoom] flag. It yields a [TeacherSearchResult] stream containing the found periods
  /// and information about the current class or room which is being loaded.
  /// The [previousResults] parameter allows passing in previously found periods will be included in the result.
  Stream<TeacherSearchResult>? findTeacher(
    UntisElementDescriptor teacher, {
    bool searchInRoom = false,
    Set<UntisPeriod> previousResults = const {},
  }) async* {
    Future<List<(UntisElementDescriptor, String)>> getSearchPlaces() async {
      return searchInRoom
          ? (await _session!.rooms).map((r) => (r.id, r.name)).toList()
          : (await _session!.classes).map((c) => (c.id, c.name)).toList();
    }

    if (teacher.type != .teacher || _session == null) {
      yield TeacherSearchResult(periods: {});
      return;
    }

    final searchPlaces = await getSearchPlaces();
    final now = DateTime.now();
    Set<UntisPeriod> foundPeriods = previousResults;
    Set<int> foundIDs = previousResults.map((p) => p.id).toSet();
    for (var (searchId, searchPlace) in searchPlaces) {
      yield TeacherSearchResult(
        currentSearchingPlace: searchPlace,
        periods: foundPeriods,
      );
      final classTimetable = await _session!.getTimetable(
        startDate: now,
        id: searchId,
      );
      classTimetable.periods
          .where((period) => period.teachers.any((t) => t.id == teacher))
          .where((period) => !foundIDs.contains(period.id))
          .forEach((period) {
            foundPeriods.add(period);
            foundIDs.add(period.id);
          });
    }
    yield TeacherSearchResult(periods: foundPeriods);
  }

  Future<DateTime?> deepNextLessonSearch(
    Subject subject,
    StreamController<DateTime> stream,
    Completer<void> abort,
  ) async {
    if (_session == null) {
      return null;
    }

    DateTime startDate = DateTime.now();
    final maxDepth = startDate.add(const Duration(days: 356));

    bool isAborted = false;
    abort.future.then((_) {
      isAborted = true;
      stream.close();
    });

    while (!isAborted) {
      stream.add(startDate);
      final timetable = await _session!.getTimetable(startDate: startDate);
      final nextLesson = timetable.periods.firstWhereOrNull(
        (period) =>
            period.subject?.id.id == subject.id &&
            !period.isCancelled &&
            period.teacher != null &&
            period.startDateTime.isAfter(DateTime.now()),
      );
      if (nextLesson != null) {
        return nextLesson.startDateTime;
      }
      startDate = startDate.add(const Duration(days: 7));
      if (startDate.isAfter(maxDepth)) {
        return null;
      }
    }
    return null;
  }

  /// This method is not implemented yet.
  void loadUntisHomeworks() {
    // Could contain test, homework information
    // also used at events, subject is needed
    // print(timetable!.periods[3].text);

    // is used to declare exams
    // print(await _session!.getExams(
    //   startDate: DateTime.now(),
    //   endDate: DateTime.now().add(const Duration(days: 30)),
    // ));

    // is used to declare homeworks, but some also annouce exams
    // print(await _session!.getHomework(
    //   startDate: DateTime.now(),
    //   endDate: DateTime.now().add(const Duration(days: 30)),
    // ));
  }
}

/// Result of a teacher search containing found periods and current searching place.
class TeacherSearchResult {
  final String? currentSearchingPlace;
  final Set<UntisPeriod> periods;

  TeacherSearchResult({this.currentSearchingPlace, required this.periods});
}
