import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/models/lesson.dart';
import '../provider/credential_provider.dart';
import '../provider/timetable_provider.dart';
import '../routes/typesafe_router.dart';
import '../utilities/enums.dart';
import '../widgets/info_box.dart';


/// Screen that shows the user's weekly timetable, built from the subjects
/// and periods retrieved via the Untis API.
class TimetableView extends StatefulWidget {
  const TimetableView({super.key});

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTimetable());
  }

  static DateTime _startOfWeek(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Triggers loading the timetable for [_weekStart] using the current
  /// Untis session.
  void _loadTimetable() {
    final credentialProvider = context.read<CredentialProvider>();
    context
        .read<TimetableProvider>()
        .updateFromSession(credentialProvider, _weekStart);
  }

  void _goToPreviousWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadTimetable();
  }

  void _goToNextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadTimetable();
  }

  void _goToCurrentWeek() {
    setState(() => _weekStart = _startOfWeek(DateTime.now()));
    _loadTimetable();
  }

  @override
  Widget build(BuildContext context) {
    final credentialProvider = context.watch<CredentialProvider>();
    final timetableProvider = context.watch<TimetableProvider>();

    // Once the Untis session becomes available (or the requested week
    // changes), get the timetable for it.
    if (credentialProvider.sessionStatus ==
        UntisSessionStatus.sessionAccomplished &&
        timetableProvider.status != UntisSubjectStatus.loading &&
        timetableProvider.loadedWeekStart != _weekStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTimetable());
    }

    final days = List.generate(5, (i) => _weekStart.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        title: Text(_weekLabel(_weekStart)),
        actions: [
          IconButton(
            tooltip: 'Aktuelle Woche',
            onPressed: _goToCurrentWeek,
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: 'Vorherige Woche',
            onPressed: _goToPreviousWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Nächste Woche',
            onPressed: _goToNextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: _buildBody(context, credentialProvider, timetableProvider, days),
    );
  }

  Widget _buildBody(
      BuildContext context,
      CredentialProvider credentialProvider,
      TimetableProvider timetableProvider,
      List<DateTime> days,
      ) {
    if (credentialProvider.sessionStatus == UntisSessionStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (credentialProvider.sessionStatus !=
        UntisSessionStatus.sessionAccomplished) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const InfoBox(
              title: 'Nicht verbunden',
              icon: Icons.link_off,
              paragraphs: [
                'Verbinde dein Untis-Konto, um deinen Stundenplan zu sehen.',
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => const EnterCredentialsRoute().go(context),
              icon: const Icon(Icons.link),
              label: const Text('Jetzt verbinden'),
            ),
          ],
        ),
      );
    }

    return switch (timetableProvider.status) {
      UntisSubjectStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      UntisSubjectStatus.error => const Padding(
        padding: EdgeInsets.all(16),
        child: InfoBox(
          title: 'Fehler',
          icon: Icons.error_outline,
          accentColor: Colors.red,
          paragraphs: [
            'Beim Laden deines Stundenplans ist ein Fehler aufgetreten. '
                'Bitte versuche es erneut.',
          ],
        ),
      ),
      _ => TimetableWidget(days: days, lessons: timetableProvider.lessons),
    };
  }

  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 4));
    String fmt(DateTime d) => '${d.day}.${d.month}.';
    return 'Stundenplan – ${fmt(weekStart)} bis ${fmt(end)}';
  }
}


/// A weekly timetable grid, similar to a calendar week view.
///
/// Each entry in [days] becomes a column; [lessons] are placed within their
/// day's column at a vertical position and height proportional to their
/// start time and duration. Tapping a lesson opens a detail sheet.
class TimetableWidget extends StatelessWidget {
  const TimetableWidget({
    super.key,
    required this.days,
    required this.lessons,
    this.dayStartHour = 8,
    this.dayEndHour = 16,
    this.hourHeight = 70,
    this.dayColumnWidth = 150,
  });

  /// The days shown as columns, typically Monday through Friday.
  final List<DateTime> days;

  /// All lessons to display. Lessons that don't fall on one of [days] are
  /// ignored.
  final List<TimetableLesson> lessons;

  /// First full hour shown on the time axis.
  final int dayStartHour;

  /// Last full hour shown on the time axis.
  final int dayEndHour;

  /// Height in logical pixels representing one hour.
  final double hourHeight;

  /// Width of each day column.
  final double dayColumnWidth;

  static const double _timeColumnWidth = 52;
  static const double _headerHeight = 56;

  double get _gridHeight => (dayEndHour - dayStartHour) * hourHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: SizedBox(
        height: _headerHeight + _gridHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeAxis(colorScheme),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in days) _buildDayColumn(context, colorScheme, day),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAxis(ColorScheme colorScheme) {
    final hourCount = dayEndHour - dayStartHour;

    return SizedBox(
      width: _timeColumnWidth,
      child: Column(
        children: [
          SizedBox(height: _headerHeight),
          Expanded(
            child: Stack(
              children: [
                for (var i = 0; i <= hourCount; i++)
                  Positioned(
                    top: i * hourHeight - 8,
                    right: 8,
                    child: Text(
                      '${dayStartHour + i}:00',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(BuildContext context, ColorScheme colorScheme, DateTime day) {
    final isToday = _isSameDay(day, DateTime.now());
    final dayLessons = lessons.where((lesson) => _isSameDay(lesson.start, day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return SizedBox(
      width: dayColumnWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Column(
          children: [
            _buildDayHeader(context, colorScheme, day, isToday),
            Expanded(
              child: ColoredBox(
                color: isToday
                    ? colorScheme.primary.withValues(alpha: 0.04)
                    : Colors.transparent,
                child: Stack(
                  children: [
                    ..._buildHourLines(colorScheme),
                    for (final lesson in dayLessons) _buildLessonCard(context, colorScheme, lesson),
                    if (isToday) _buildNowIndicator(colorScheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, ColorScheme colorScheme, DateTime day, bool isToday) {
    const weekdayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Container(
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekdayNames[day.weekday - 1],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isToday ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)
                : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHourLines(ColorScheme colorScheme) {
    final hourCount = dayEndHour - dayStartHour;
    return [
      for (var i = 1; i < hourCount; i++)
        Positioned(
          top: i * hourHeight,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
    ];
  }

  Widget _buildLessonCard(BuildContext context, ColorScheme colorScheme, TimetableLesson lesson) {
    final top = _minutesFromDayStart(lesson.start) / 60 * hourHeight;
    final height = lesson.duration.inMinutes / 60 * hourHeight;

    final isCancelled = lesson.state == LessonState.cancelled;
    final isSubstitution = lesson.state == LessonState.substitution;
    final isExam = lesson.state == LessonState.exam;

    final subjectColor = _colorForSubject(lesson.subjectShortName);
    final backgroundColor = isCancelled
        ? colorScheme.surfaceContainerHighest
        : subjectColor.withValues(alpha: 0.16);
    final accentColor = isCancelled
        ? colorScheme.outline
        : isSubstitution
        ? Colors.orange
        : subjectColor;

    return Positioned(
      top: top + 1,
      left: 2,
      right: 2,
      height: (height - 2).clamp(0, double.infinity),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showLessonDetails(context, lesson),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accentColor, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lesson.subjectShortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    color: isCancelled ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                  ),
                ),
                if (height > 36)
                  Text(
                    lesson.room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                if (height > 52 && isExam)
                  Text(
                    'Klausur',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNowIndicator(ColorScheme colorScheme) {
    final now = DateTime.now();
    final minutes = (now.hour - dayStartHour) * 60 + now.minute;
    if (minutes < 0 || minutes > (dayEndHour - dayStartHour) * 60) {
      return const SizedBox.shrink();
    }

    final top = minutes / 60 * hourHeight;
    return Positioned(
      top: top - 4,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Container(height: 1.5, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  double _minutesFromDayStart(DateTime dateTime) {
    return ((dateTime.hour - dayStartHour) * 60 + dateTime.minute).toDouble();
  }
}


void _showLessonDetails(BuildContext context, TimetableLesson lesson) {
  final colorScheme = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _colorForSubject(lesson.subjectShortName),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lesson.subjectName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(
              context,
              Icons.access_time,
              '${_formatTime(lesson.start)} – ${_formatTime(lesson.end)} Uhr',
            ),
            const SizedBox(height: 8),
            _detailRow(context, Icons.location_on_outlined, 'Raum ${lesson.room}'),
            if (lesson.teacher != null) ...[
              const SizedBox(height: 8),
              _detailRow(context, Icons.person_outline, lesson.teacher!),
            ],
            if (lesson.state == LessonState.cancelled) ...[
              const SizedBox(height: 16),
              _statusBanner(Icons.event_busy, 'Diese Stunde entfällt.', colorScheme.error),
            ] else if (lesson.state == LessonState.substitution) ...[
              const SizedBox(height: 16),
              _statusBanner(Icons.swap_horiz, 'Vertretung', Colors.orange),
            ] else if (lesson.state == LessonState.exam) ...[
              const SizedBox(height: 16),
              _statusBanner(Icons.edit_note, 'Klassenarbeit / Prüfung', colorScheme.primary),
            ],
          ],
        ),
      );
    },
  );
}

Widget _detailRow(BuildContext context, IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 10),
      Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

Widget _statusBanner(IconData icon, String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Subject colors:

const List<Color> _subjectColorPalette = [
  Color(0xFF5C6BC0), // Indigo
  Color(0xFF42A5F5), // Blue
  Color(0xFF26A69A), // Teal
  Color(0xFF66BB6A), // Green
  Color(0xFFFFA726), // Orange
  Color(0xFFEF5350), // Red
  Color(0xFFAB47BC), // Purple
  Color(0xFF8D6E63), // Brown
  Color(0xFF26C6DA), // Cyan
  Color(0xFFEC407A), // Pink
];

/// Picks a stable color for a subject based on its short name, so the same
/// subject always gets the same color without needing to store one.
Color _colorForSubject(String key) {
  final index = key.hashCode.abs() % _subjectColorPalette.length;
  return _subjectColorPalette[index];
}