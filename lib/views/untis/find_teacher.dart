import 'package:collection/collection.dart';
import 'package:dart_untis_mobile/dart_untis_mobile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../provider/untis_provider.dart';

class FindTeacher extends StatefulWidget {
  final UntisElementDescriptor teacher;
  const FindTeacher({super.key, required this.teacher});

  @override
  State<FindTeacher> createState() => _FindTeacherState();
}

class _FindTeacherState extends State<FindTeacher> {
  Stream<TeacherSearchResult>? _stream;
  UntisTeacher? _teacher;
  bool _lookingInRooms = false;
  Set<UntisPeriod> _previousResults = {};

  void initStream() {
    if (_teacher != null) return;
    final UntisProvider provider = context.watch();
    _teacher = provider.untisTeachers.firstWhereOrNull(
      (t) => t.id == widget.teacher,
    );
    if (_teacher != null) {
      _stream = provider.findTeacher(widget.teacher);
    }
  }

  void lookAtRooms(Set<UntisPeriod> previousResults) {
    if (_teacher == null) return;
    final UntisProvider provider = context.read();
    setState(() {
      _previousResults = previousResults;
      _lookingInRooms = true;
      _stream = provider.findTeacher(
        _teacher!.id,
        searchInRoom: true,
        previousResults: previousResults,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    initStream();
    if (_teacher == null) {
      // TODO switch status
      return Scaffold(
        appBar: AppBar(title: Text('Fehler')),
        body: Center(
          child: Text('Kein Lehrer mit ID: ${widget.teacher.id} gefunden'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Stundenplan von ${_teacher!.fullName}')),
      body: StreamBuilder<TeacherSearchResult>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            Sentry.captureException(
              snapshot.error,
              stackTrace: snapshot.stackTrace,
            );
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data!;
          return _buildResult(result);
        },
      ),
    );
  }

  ListView _buildResult(TeacherSearchResult result) {
    final periods = result.periods.toList()
      ..addAll(_previousResults.toList())
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    List<Widget> widgets = [];

    for (var index = 0; index < periods.length; index++) {
      if (index == 0 ||
          periods[index].startDateTime.day !=
              periods[index - 1].startDateTime.day) {
        widgets.add(_formatDate(periods[index]));
      }
      widgets.add(_buildTile(periods[index]));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [...widgets, Divider(), _buildInfo(result)],
    );
  }

  Widget _formatDate(UntisPeriod period) {
    return Row(
      children: [
        SizedBox(width: 30, child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            '${period.startDateTime.day.toString().padLeft(2, '0')}.${period.startDateTime.month.toString().padLeft(2, '0')}.${period.startDateTime.year}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildInfo(TeacherSearchResult result) {
    if (result.currentClass == null) {
      return Column(
        children: [
          result.periods.isEmpty
              ? const Center(child: Text('Es wurden keine Einträge gefunden'))
              : const Center(child: Text('Keine weiteren Einträge gefunden')),
          if (!_lookingInRooms)
            TextButton(
              onPressed: () => lookAtRooms(result.periods),
              child: Text('Auch Raumpläne durchsuchen'),
            ),
        ],
      );
    } else {
      final article = _lookingInRooms ? 'von' : 'der';
      return Center(
        child: Text('Schaue im Stundenplan $article ${result.currentClass}'),
      );
    }
  }

  ListTile _buildTile(UntisPeriod period) {
    String rooms = period.rooms.map((r) => r.name).join(', ');
    if (rooms.isEmpty) {
      rooms = 'Kein Raum angegeben';
    }
    String? subtitle = period.subject?.longName;
    final String classes = period.classes.map((c) => c.name).join(', ');
    if (classes.isNotEmpty) {
      subtitle = '${subtitle ?? ''} bei $classes';
    }
    final canceledStyle = TextStyle(
      decoration: TextDecoration.lineThrough,
      decorationColor: Theme.of(context).colorScheme.onError,
      decorationThickness: 4,
      color: Theme.of(context).colorScheme.error,
    );
    final isCanceled = period.isCancelled;
    return ListTile(
      title: Text(rooms, style: isCanceled ? canceledStyle : null),
      subtitle: Text(
        subtitle?.trim() ?? 'Ohne Fach oder Klasse',
        style: isCanceled ? canceledStyle : null,
      ),
      trailing: Text(
        '${_formatTime(period.startDateTime)} - ${_formatTime(period.endDateTime)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
