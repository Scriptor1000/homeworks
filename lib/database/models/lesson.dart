/// The state of a single lesson, as reported by the Untis timetable.
enum LessonState {
  /// A normal lesson that takes place as planned.
  regular,

  /// The lesson has been cancelled and does not take place.
  cancelled,

  /// The lesson takes place, but with a substitute teacher and/or room.
  substitution,

  /// The lesson is (or contains) an exam / written assessment.
  exam,
}

/// Represents a single scheduled lesson/period in the timetable.
///
/// This is a lightweight, UI-focused model used by [TimetableWidget]. It is
/// populated from [UntisPeriod]s by `TimetableProvider`.
class TimetableLesson {
  /// Short subject code shown on the lesson card, e.g. "M" for Mathematik.
  final String subjectShortName;

  /// Full subject name shown in the detail view, e.g. "Mathematik".
  final String subjectName;

  /// Room the lesson takes place in.
  final String room;

  /// Name of the teacher, if known.
  final String? teacher;

  /// Date & time the lesson starts.
  final DateTime start;

  /// Date & time the lesson ends.
  final DateTime end;

  /// Whether the lesson is regular, cancelled, substituted, or an exam.
  final LessonState state;

  const TimetableLesson({
    required this.subjectShortName,
    required this.subjectName,
    required this.room,
    this.teacher,
    required this.start,
    required this.end,
    this.state = LessonState.regular,
  });

  /// How long the lesson takes.
  Duration get duration => end.difference(start);
}